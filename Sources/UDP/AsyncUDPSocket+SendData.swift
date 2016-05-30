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


public let kAsyncUDPSocketSendNoTimeout: NSTimeInterval = -1.0
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
    public func send(data: NSData, host: String, port: UInt16, timeout: NSTimeInterval = kAsyncUDPSocketSendNoTimeout, tag: Int = kAsyncUDPSocketSendNoTag) {

        if data.length == 0 {
            return
        }

        let packet = AsyncUDPSendPacket(data: data, timeout: timeout, tag: tag)
        packet.resolveInProgress = true

        resolve(host, port: port) { (address, error) -> Void in

            packet.resolveInProgress = false
            packet.resolvedAddress = address
            packet.resolvedError = error

            let family: Int32 = host.characters.split(":").count > 1 ? AF_INET6 : AF_INET
            packet.resolvedFamily = family

            if let curSend = self.currentSend {
                if packet == curSend {
                    self.doPreSend()
                }
            }
        }

        dispatch_async(self.socketQueue) { () -> Void in
            self.sendQueue.append(packet)
            self.maybeDequeueSend()
        }

    }

}

//MARK: - Private

private extension AsyncUDPSocket {


    private func resolve(host: String, port: UInt16, handler: (address: UnsafePointer<sockaddr>?, error: SendReceiveErrors?) -> Void) {

        let globalConcurrentQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)


        dispatch_async(globalConcurrentQ) { () -> Void in
            var addrInfo: UnsafeMutablePointer<addrinfo> = UnsafeMutablePointer<addrinfo>(nil)

            let family: Int32 = host.characters.split(":").count > 1 ? AF_INET6 : AF_INET
            let hostStr = host.cStringUsingEncoding(NSUTF8StringEncoding)
            let portStr = String(port).cStringUsingEncoding(NSUTF8StringEncoding)


            var hints = addrinfo(
                ai_flags: AI_NUMERICHOST,   //no name resolution
                ai_family: family,
                ai_socktype: SOCK_DGRAM,
                ai_protocol: IPPROTO_UDP,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil)

            let gaiError = getaddrinfo(hostStr!, portStr!, &hints, &addrInfo)

            if gaiError != 0 {

                if let errorMsg = String.fromCString(gai_strerror(gaiError)) {
                    dispatch_async(self.socketQueue) { () -> Void in
                        handler(address: nil, error: SendReceiveErrors.ResolveIssue(msg: errorMsg))
                    }
                }

            } else {

                dispatch_async(self.socketQueue) { () -> Void in
                    handler(address: addrInfo.memory.ai_addr, error: nil)
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
                let err = SendReceiveErrors.NotBound(msg: "Socket Must be bound and created prior to sending")
                notifyDidNotSend(err, tag: kAsyncUDPSocketSendNoTag)
                return
            }

            while sendQueue.count > 0 {

                currentSend = sendQueue.first
                sendQueue.removeAtIndex(0)

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
                self.closeSocketError(SocketCloseErrors.Error(msg: "Nothing more to Send"))
            }
        }
    }

    private func notifyDidNotSend(error: SendReceiveErrors, tag: Int) {

        for observer in observers {
            //Observer decides which queue it will send back on
            observer.socketDidNotSend(self, tag: tag, error: error)
        }
    }

    private func notifyDidSend(tag: Int) {

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
            dispatch_source_cancel(sendTimer!)
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

        let buffer = (currentSend?.buffer.bytes)!
        let bufferSize = (currentSend?.buffer.length)!
        let dst = (currentSend?.resolvedAddress)!

        result = sendto(sockfd, buffer, bufferSize, 0, dst, socklen_t(dst.memory.sa_len) )

        //Check Results
        var waitingForSocket: Bool = false
        var socketError: SendReceiveErrors?

        if result == 0 {
            waitingForSocket = true
        } else if result < 0 {

            if errno == EAGAIN {
                waitingForSocket = true
            } else {
                socketError = SendReceiveErrors.SendIssue(msg: "Error in sendTo Function")
            }
        }

        if waitingForSocket == true {

            if !flags.contains(.sockCanAccept) {
                resumeSendSource()
            }

            if sendTimer == nil && currentSend?.timeout >= 0.0 {
                setupSendTimer((currentSend?.timeout)!)
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

            dispatch_suspend(source)

            flags.insert(.sendSourceSuspend)

        }
    }

    internal func resumeSendSource() {

        if flags.contains(.sendSourceSuspend).boolValue == true {

            guard let source = self.sendSource else { return }

            dispatch_resume(source)
            
            flags.remove(.sendSourceSuspend)
        }
    }

    //MARK: Send Timeout
    private func setupSendTimer(timeout: NSTimeInterval) {

        assert(sendTimer == nil, "Invalid Logic")
        assert(timeout >= 0.0, "Invalid Logic")

        sendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, socketQueue)

        dispatch_source_set_event_handler(sendTimer!) { () -> Void in
            self.doSendTimout()
        }

        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * Double(NSEC_PER_SEC)))

        dispatch_source_set_timer(sendTimer!, when, DISPATCH_TIME_FOREVER, 0);
        dispatch_resume(sendTimer!);

    }

    private func doSendTimout() {
        let error = SendReceiveErrors.SendTimout(msg: "Send operation timed out")

        notifyDidNotSend(error, tag: (currentSend?.tag)!)
        endCurrentSend()
        maybeDequeueSend()

    }
}

