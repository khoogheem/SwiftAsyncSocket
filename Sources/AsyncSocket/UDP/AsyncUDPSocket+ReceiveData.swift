//
//  AsyncUDPSocket+ReceiveData.swift
//  SwiftAsyncSocket
//
//  Created by Kevin Hoogheem on 12/13/15.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/**
 ReceiveData Extends AsyncUDPSocket

*/
public extension AsyncUDPSocket {
    
    /**
     Receive One UDP Packet at a time
     */
    public func receiveOnce() throws {

        var errorCode: SendReceiveErrors?

        let block: dispatch_block_t = {

            if self.flags.contains(UdpSocketFlags.receiveContinous).boolValue == true {
                errorCode = SendReceiveErrors.AlreadyReceiving(msg: "Already Receiving Data.. Must Pause before calling receiveOnce")
                return
            }

            if self.flags.contains(UdpSocketFlags.receiveOnce).boolValue == false {

                if self.flags.contains(UdpSocketFlags.didCreateSockets).boolValue == false {
                    errorCode = SendReceiveErrors.NotBound(msg: "You must bind the Socket prior to Receiving")
                    return
                }

                self.flags.remove(UdpSocketFlags.receiveContinous)

                #if swift(>=3.0)
                    _ = self.flags.insert(UdpSocketFlags.receiveOnce)
                #else
                    self.flags.insert(UdpSocketFlags.receiveOnce)
                #endif

                //Continue to receive
                dispatch_async(self.socketQueue, { () -> Void in
                    self.doReceive()
                })
            }
        }

        if isCurrentQueue == true {
            block()
        } else {
            dispatch_async(socketQueue, block)
        }

        if let errors = errorCode {
            throw errors
        }
    }

    /**
     Continous receive of UDP Packets
     */
    public func beginReceiving() throws {

        var errorCode: SendReceiveErrors?

        let block: dispatch_block_t = {

            if self.flags.contains(UdpSocketFlags.receiveContinous).boolValue == false {

                if self.flags.contains(UdpSocketFlags.didCreateSockets).boolValue == false {
                    errorCode = SendReceiveErrors.NotBound(msg: "You must bind the Socket prior to Receiving")
                    return
                }

                self.flags.remove(UdpSocketFlags.receiveOnce)
                #if swift(>=3.0)
                    _ = self.flags.insert(UdpSocketFlags.receiveContinous)
                #else
                    self.flags.insert(UdpSocketFlags.receiveContinous)
                #endif

                //Continue to receive
                dispatch_async(self.socketQueue, { () -> Void in
                    self.doReceive()
                })
            }
        }

        if isCurrentQueue == true {
            block()
        } else {
            dispatch_sync(socketQueue, block)
        }

        if let errors = errorCode {
            throw errors
        }

    }

    /**
     Pause Receiving UDP Packets.

     Once called it will pause any new UDP Packets, however there may be packets queued up that will still come in.  Once this is called you will need to call one of the receive functions to start receiving again.
     */
    public func pauseReceiving() {

        let block: dispatch_block_t = {

            self.flags.remove(UdpSocketFlags.receiveOnce)
            self.flags.remove(UdpSocketFlags.receiveContinous)

            if self.socketBytesAvailable > 0 {
                self.suspendReceive()
            }
        }
        
        if isCurrentQueue == true {
            block()
        } else {
            dispatch_async(socketQueue, block)
        }
    }
    

}


//MARK: - Suspend/Receive
internal extension AsyncUDPSocket {

    internal func suspendReceive() {

        if flags.contains(.recvSourceSuspend).boolValue == false {

            if let source = receiveSource {
                ASLog("dispatch_suspend(receiveSource)")

                dispatch_suspend(source)

                #if swift(>=3.0)
                    _ = flags.insert(.recvSourceSuspend)
                #else
                    flags.insert(.recvSourceSuspend)
                #endif

            }
        }
    }

    internal func resumeReceive() {

        if flags.contains(.recvSourceSuspend).boolValue == true {

            if let source = receiveSource {

                dispatch_resume(source)

                flags.remove(.recvSourceSuspend)
            }
        }
    }
    
    internal func doReceive() {

        if (flags.contains(UdpSocketFlags.receiveContinous) || flags.contains(UdpSocketFlags.receiveOnce)) == false {
            ASLog("Receiving is paused")

            if socketBytesAvailable > 0 {
                suspendReceive()
            }

            return
        }

        //No Data
        if socketBytesAvailable == 0 {
            resumeReceive()
            return
        }

        assert(socketBytesAvailable > 0, "Invalid Logic")

        //Socket IO
        var socketAddress = sockaddr_storage()
        var socketAddressLength = socklen_t(sizeof(sockaddr_storage.self))
        #if swift(>=3.0)
            let response = [UInt8](repeating: 0, count: maxReceiveSize)
        #else
            let response = [UInt8](count: maxReceiveSize, repeatedValue: 0)
        #endif

        guard let source = self.receiveSource else { return }
        let UDPSocket = Int32(dispatch_source_get_handle(source))


        let bytesRead = withUnsafeMutablePointer(&socketAddress) {
            recvfrom(UDPSocket, UnsafeMutablePointer<Void>(response), response.count, 0, UnsafeMutablePointer($0), &socketAddressLength)
        }


        var waitingForSocket: Bool = false
        var notifyDelegate: Bool = false

        if bytesRead == 0 {
            waitingForSocket = true
        } else if (bytesRead < 0) {
            if errno == EAGAIN {
                waitingForSocket = true
            } else {
                closeSocketFinal()
                return
            }

        } else {
            #if swift(>=3.0)
                guard let endpoint = withUnsafePointer(&socketAddress, { self.getEndpointFromSocketAddress(socketAddressPointer: UnsafePointer($0)) }) else {
                    ASLog("Failed to get the address and port from the socket address received from recvfrom")
                    //            closeSocketFinal()
                    return
                }
            #else
                guard let endpoint = withUnsafePointer(&socketAddress, { self.getEndpointFromSocketAddress(UnsafePointer($0)) }) else {
                ASLog("Failed to get the address and port from the socket address received from recvfrom")
                //            closeSocketFinal()
                return
                }
            #endif


            let responseDatagram = NSData(bytes: UnsafePointer<Void>(response), length: bytesRead)

            if UInt(bytesRead) > socketBytesAvailable {
                socketBytesAvailable = 0
            } else {
                socketBytesAvailable -= UInt(bytesRead)
            }

            //no errors go ahead and notify
            #if swift(>=3.0)
                notifyRecieveDelegate(data: responseDatagram, fromHost: endpoint.host, port: endpoint.port)
            #else
                notifyRecieveDelegate(responseDatagram, fromHost: endpoint.host, port: endpoint.port)
            #endif

            notifyDelegate = true
        }

        if waitingForSocket == true {
            resumeReceive()
        } else {

            if flags.contains(UdpSocketFlags.receiveContinous).boolValue == true {

                doReceive()

            } else {

                if notifyDelegate == true {

                    flags.remove(UdpSocketFlags.receiveOnce)
                }
            }
        }

    }

    internal func doReceiveEOF() {
        closeSocketFinal()
    }


    internal func notifyRecieveDelegate(data: NSData, fromHost: String, port: UInt16) {

        for observer in observers {
            //Observer decides which queue it will send back on
            #if swift(>=3.0)
                observer.socketDidReceive(socket: self, data: data, fromHost: fromHost, onPort: port)
            #else
                observer.socketDidReceive(self, data: data, fromHost: fromHost, onPort: port)
            #endif
        }
    }
}

private extension AsyncUDPSocket {


    /// Convert a sockaddr structure into an IP address string and port.
    func getEndpointFromSocketAddress(socketAddressPointer: UnsafePointer<sockaddr>) -> (host: String, port: UInt16)? {
        
        #if swift(>=3.0)
            let family = Int32(socketAddressPointer.pointee.sa_family)
        #else
            let family = Int32(socketAddressPointer.memory.sa_family)
        #endif


        switch family {
        case AF_INET:

            #if swift(>=3.0)
                var socketAddressInet = UnsafePointer<sockaddr_in>(socketAddressPointer).pointee
                let length = Int(NI_MAXHOST)
                let buffer = UnsafeMutablePointer<Int8>.init(bitPattern: 0)
                defer {
                    buffer?.deinitialize()
                    buffer?.deallocateCapacity(1)
                }
            #else
                var socketAddressInet = UnsafePointer<sockaddr_in>(socketAddressPointer).memory
                let length = Int(NI_MAXHOST)
                let buffer = UnsafeMutablePointer<Int8>.alloc(Int(1))
                defer {
                    buffer.destroy()
                    buffer.dealloc(1)
                }
            #endif

            var hostCString = UnsafePointer<Int8>(nil)

            hostCString = inet_ntop(AF_INET, &socketAddressInet.sin_addr, buffer, socklen_t(length))

            let port = UInt16(socketAddressInet.sin_port).byteSwapped
            let newHost = UnsafePointer<CChar>(hostCString)

            #if swift(>=3.0)
                if let host = newHost {
                    return (String(cString: host), port)
                } else {
                    return nil
                }
            #else
                if let host = String.fromCString(newHost) {
                    return (host, port)
                } else {
                    return nil
                }
            #endif


        case AF_INET6:
            let length = Int(INET6_ADDRSTRLEN) + 2
            #if swift(>=3.0)
                var socketAddressInet6 = UnsafePointer<sockaddr_in6>(socketAddressPointer).pointee
                let buffer = UnsafeMutablePointer<Int8>.init(bitPattern: 0)

                defer {
                    buffer?.deinitialize()
                    buffer?.deallocateCapacity(1)
                }
            #else
                var socketAddressInet6 = UnsafePointer<sockaddr_in6>(socketAddressPointer).memory
                let buffer = UnsafeMutablePointer<Int8>.alloc(Int(1))

                defer {
                    buffer.destroy()
                    buffer.dealloc(1)
                }
            #endif


            let hostCString = inet_ntop(AF_INET6, &socketAddressInet6.sin6_addr, buffer, socklen_t(length))
            let port = UInt16(socketAddressInet6.sin6_port).byteSwapped

            #if swift(>=3.0)
                if let host = hostCString {
                    return (String(cString: host), port)
                } else {
                    return nil
                }
            #else
                if let host = String.fromCString(newHost) {
                    return (host, port)
                } else {
                    return nil
                }

            #endif

        default:
            return nil
        }
    }

}
