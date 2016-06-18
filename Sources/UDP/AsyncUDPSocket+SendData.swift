//
//  AsyncUDPSocket+SendData.swift
//  SwiftAsyncSocket
//
//  Created by Kevin Hoogheem on 12/26/15.
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


public let kAsyncUDPSocketSendNoTimeout: TimeInterval = -1.0
public let kAsyncUDPSocketSendNoTag: Int = 0

/** 
 SendData Extends AsyncUDPSocket

*/
public extension AsyncUDPSocket {

    /**
     Send Data

     - parameter data: Data to Send
     - parameter host: Host to Send Data to
     - parameter port: Port on which to send
     - parameter timeout: Time interval to consider send a failure
     - parameter tag: A Tag to use on the send.  This can be examined when you get the observer

     */
    public func send(_ data: Data, host: String, port: UInt16, timeout: TimeInterval = kAsyncUDPSocketSendNoTimeout, tag: Int = kAsyncUDPSocketSendNoTag) {

        if data.count == 0 {
            return
        }

        let packet = AsyncUDPSendPacket(data: data, timeout: timeout, tag: tag)
        packet.resolveInProgress = true


        #if swift(>=3.0)
            resolve(host, port: port) { (address, error) -> Void in

                packet.resolveInProgress = false
                packet.resolvedAddress = address
                packet.resolvedError = error

                let family: Int32 = host.components(separatedBy: ":").count > 1 ? AF_INET6 : AF_INET

                packet.resolvedFamily = family

                if let curSend = self.currentSend {
                    if packet == curSend {
                        self.doPreSend()
                    }
                }
            }
        #else
            resolve(host, port: port) { (address, error) -> Void in

                packet.resolveInProgress = false
                packet.resolvedAddress = address
                packet.resolvedError = error

                let family: Int32 = host.characters.split(separator: ":").count > 1 ? AF_INET6 : AF_INET

                packet.resolvedFamily = family

                if let curSend = self.currentSend {
                    if packet == curSend {
                        self.doPreSend()
                    }
                }
            }
        #endif


        self.socketQueue.async { () -> Void in
            self.sendQueue.append(packet)
            self.maybeDequeueSend()
        }

    }

}

//MARK: - Private

private extension AsyncUDPSocket {


    private func resolve(_ host: String, port: UInt16, handler: (address: UnsafePointer<sockaddr>?, error: SendReceiveErrors?) -> Void) {

        let globalConcurrentQ = DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosDefault)


        globalConcurrentQ.async { () -> Void in
            #if swift(>=3.0)
                var addrInfo: UnsafeMutablePointer<addrinfo>? = UnsafeMutablePointer<addrinfo>(allocatingCapacity: 1)

                let family: Int32 = host.components(separatedBy: ":").count > 1 ? AF_INET6 : AF_INET
                let hostStr = host.cString(using: String.Encoding.utf8)
                let portStr = String(port).cString(using: String.Encoding.utf8)
            #else
                var addrInfo: UnsafeMutablePointer<addrinfo> = UnsafeMutablePointer<addrinfo>(nil)
                let family: Int32 = host.characters.split(separator: ":").count > 1 ? AF_INET6 : AF_INET
                let hostStr = host.cString(using: String.Encoding.utf8)
                let portStr = String(port).cString(using: String.Encoding.utf8)
            #endif


            var hints = addrinfo(
                ai_flags: AI_NUMERICHOST,   //no name resolution
                ai_family: family,
                ai_socktype: ASSocketType.dataGram.value,
                ai_protocol: ASIPProto.udp.value,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil)

            let gaiError = getaddrinfo(hostStr!, portStr!, &hints, &addrInfo)

            if gaiError != 0 {

                if let errorMsg = String(validatingUTF8: gai_strerror(gaiError)) {
                    self.socketQueue.async { () -> Void in
                        handler(address: nil, error: SendReceiveErrors.resolveIssue(msg: errorMsg))
                    }
                }


            } else {

                self.socketQueue.async { () -> Void in

                    #if swift(>=3.0)
                        handler(address: addrInfo?.pointee.ai_addr, error: nil)
                    #else
                        handler(address: addrInfo.pointee.ai_addr, error: nil)
                    #endif
                    

                    freeaddrinfo(addrInfo)
                    
                }
                
            }

        }


    }

    private func maybeDequeueSend() {

        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            return
        }

        if currentSend == nil {

            guard flags.contains(.didCreateSockets) == true else {
                //throw error here
                let err = SendReceiveErrors.notBound(msg: "Socket Must be bound and created prior to sending")
                notifyDidNotSend(err, tag: kAsyncUDPSocketSendNoTag)

                return
            }

            while sendQueue.count > 0 {

                currentSend = sendQueue.first
                #if swift(>=3.0)
                    sendQueue.remove(at: 0)
                #else
                    sendQueue.remove(at: 0)
                #endif


                //Check for Errors in resolv
                if currentSend?.resolvedError != nil {
                    notifyDidNotSend((currentSend?.resolvedError)!, tag: kAsyncUDPSocketSendNoTag)

                    currentSend = nil
                    continue
                } else {
                    //do presend!
                    doPreSend()
                    break
                }

            }

            if currentSend == nil && flags.contains(.closeAfterSend) {
                self.closeSocketError(SocketCloseErrors.error(msg: "Nothing more to Send"))
            }
        }
    }

    private func notifyDidNotSend(_ error: SendReceiveErrors, tag: Int) {

        for observer in observers {
            //Observer decides which queue it will send back on
            observer.socketDidNotSend(self, tag: tag, error: error)

        }
    }

    private func notifyDidSend(_ tag: Int) {

        for observer in observers {
            //Observer decides which queue it will send back on
            observer.socketDidSend(self, tag: tag)
        }
    }

}

//MARK: PreSend
private extension AsyncUDPSocket {


    private func doPreSend() {

        //Check for any problems with Send Packet

        var waitingForResolve: Bool = false
        var error: SendReceiveErrors?


        if currentSend?.resolveInProgress == true {
            waitingForResolve = true
        } else if currentSend?.resolvedError != nil {
            error = (currentSend?.resolvedError!)!
        } else if currentSend?.resolvedAddress == nil {
            waitingForResolve = true
        }

        if waitingForResolve == true {

            if flags.contains(.sockCanAccept) {
                suspendSendSource()
                return
            }
        }

        if let errors = error {
            notifyDidNotSend(errors, tag: (currentSend?.tag)!)

            endCurrentSend()
            maybeDequeueSend()
            return
        }

        //Add in filters later
        doSend()
    }


    private func endCurrentSend() {

        if sendTimer != nil {
            sendTimer!.cancel()
            sendTimer = nil
        }

        currentSend = nil
    }

}

//MARK: - Internal
//MARK: Sending
internal extension AsyncUDPSocket {

    internal func doSend() {
        
        var result: Int = 0

        assert(currentSend != nil, "Invalid Logic")

        let buffer = (((currentSend?.buffer)! as NSData).bytes)
        let bufferSize = (currentSend?.buffer.count)!
        let dst = (currentSend?.resolvedAddress)!

        #if swift(>=3.0)
            result = sendto(sockfd, buffer, bufferSize, 0, dst, socklen_t(dst.pointee.sa_len) )
        #else
            result = sendto(sockfd, buffer, bufferSize, 0, dst, socklen_t(dst.pointee.sa_len) )
        #endif


        //Check Results
        var waitingForSocket: Bool = false
        var socketError: SendReceiveErrors?

        if result == 0 {
            waitingForSocket = true
        } else if result < 0 {

            if errno == EAGAIN {
                waitingForSocket = true
            } else {
                socketError = SendReceiveErrors.sendIssue(msg: "Error in sendTo Function")
            }
        }

        if waitingForSocket == true {

            if !flags.contains(.sockCanAccept) {
                resumeSendSource()
            }

            if sendTimer == nil && currentSend?.timeout >= 0.0 {
                #if swift(>=3.0)
                    setupSendTimer((currentSend?.timeout)!)
                #else
                    setupSendTimer((currentSend?.timeout)!)
                #endif

            }
        } else if socketError != nil {
            closeSocketError(socketError)

        } else {
            let tag = (currentSend?.tag)!

            notifyDidSend(tag)

            endCurrentSend()
            maybeDequeueSend()
        }

    }


    internal func suspendSendSource() {

        if flags.contains(.sendSourceSuspend).boolValue == false {

            guard let source = self.sendSource else { return }

            source.suspend()

            #if swift(>=3.0)
                _ = flags.insert(.sendSourceSuspend)
            #else
                flags.insert(.sendSourceSuspend)
            #endif

        }
    }

    internal func resumeSendSource() {

        if flags.contains(.sendSourceSuspend).boolValue == true {

            guard let source = self.sendSource else { return }

            source.resume()
            
            flags.remove(.sendSourceSuspend)
        }
    }

    //MARK: Send Timeout
    private func setupSendTimer(_ timeout: TimeInterval) {

        assert(sendTimer == nil, "Invalid Logic")
        assert(timeout >= 0.0, "Invalid Logic")

        let timerFlag = DispatchSource.TimerFlags(rawValue: 0)

        sendTimer = DispatchSource.timer(flags: timerFlag, queue: socketQueue)

        sendTimer!.setEventHandler { () -> Void in
            self.doSendTimout()
        }

        let when = DispatchTime.now() + Double(Int64(timeout * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

//        sendTimer!.setTimer(start: when, interval: DispatchTime.distantFuture, leeway: 0);
        sendTimer!.resume();

    }

    private func doSendTimout() {
        let error = SendReceiveErrors.sendTimout(msg: "Send operation timed out")

        notifyDidNotSend(error, tag: (currentSend?.tag)!)

        endCurrentSend()
        maybeDequeueSend()

    }
}

