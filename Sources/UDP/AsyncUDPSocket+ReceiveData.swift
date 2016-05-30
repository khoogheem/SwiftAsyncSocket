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
import Darwin

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
                self.flags.insert(UdpSocketFlags.receiveOnce)

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
                self.flags.insert(UdpSocketFlags.receiveContinous)

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
                NSLog("dispatch_suspend(receiveSource)")

                dispatch_suspend(source)

                flags.insert(.recvSourceSuspend)
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
            NSLog("Receiving is paused")

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
        let response = [UInt8](count: maxReceiveSize, repeatedValue: 0)
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
            guard let endpoint = withUnsafePointer(&socketAddress, { self.getEndpointFromSocketAddress(UnsafePointer($0)) }) else {
                NSLog("Failed to get the address and port from the socket address received from recvfrom")
                //            closeSocketFinal()
                return
            }


            let responseDatagram = NSData(bytes: UnsafePointer<Void>(response), length: bytesRead)

            if UInt(bytesRead) > socketBytesAvailable {
                socketBytesAvailable = 0
            } else {
                socketBytesAvailable -= UInt(bytesRead)
            }

            //no errors go ahead and notify
            notifyRecieveDelegate(responseDatagram, fromHost: endpoint.host, port: endpoint.port)
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
            observer.socketDidReceive(self, data: data, fromHost: fromHost, onPort: port)
        }
    }
}

private extension AsyncUDPSocket {


    /// Convert a sockaddr structure into an IP address string and port.
    func getEndpointFromSocketAddress(socketAddressPointer: UnsafePointer<sockaddr>) -> (host: String, port: UInt16)? {
        
        let family = Int32(socketAddressPointer.memory.sa_family)

        switch family {
        case AF_INET:

            var socketAddressInet = UnsafePointer<sockaddr_in>(socketAddressPointer).memory
            let length = Int(NI_MAXHOST)
            let buffer = UnsafeMutablePointer<Int8>.alloc(Int(1))
            defer {
                buffer.destroy()
                buffer.dealloc(1)
            }

            var hostCString = UnsafePointer<Int8>(nil)

            hostCString = inet_ntop(AF_INET, &socketAddressInet.sin_addr, buffer, socklen_t(length))

            let port = UInt16(socketAddressInet.sin_port).byteSwapped
            let newHost = UnsafePointer<CChar>(hostCString)

            if let host = String.fromCString(newHost) {
                return (host, port)
            } else {
                return nil
            }

        case AF_INET6:
            var socketAddressInet6 = UnsafePointer<sockaddr_in6>(socketAddressPointer).memory
            let length = Int(INET6_ADDRSTRLEN) + 2
            let buffer = UnsafeMutablePointer<Int8>.alloc(Int(1))
            defer {
                buffer.destroy()
                buffer.dealloc(1)
            }

            let hostCString = inet_ntop(AF_INET6, &socketAddressInet6.sin6_addr, buffer, socklen_t(length))
            let port = UInt16(socketAddressInet6.sin6_port).byteSwapped

            if let host = String.fromCString(hostCString) {
                return (host, port)
            } else {
                return nil
            }

        default:
            return nil
        }
    }

}
