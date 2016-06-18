//
//  UDPSocket+Internal.swift
//  SwiftAsyncSocket
//
//  Created by Kevin Hoogheem on 12/11/15.
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

internal class AsyncUDPSendPacket {

    internal var resolveInProgress: Bool = false

    internal var resolvedAddress: UnsafePointer<sockaddr>?
    internal var resolvedError: AsyncUDPSocket.SendReceiveErrors?
    internal var resolvedFamily: Int32 = AF_INET

    internal let buffer: Data
    internal let timeout: TimeInterval
    internal let tag: Int

    internal init(data: Data, timeout: TimeInterval = kAsyncUDPSocketSendNoTimeout, tag: Int = kAsyncUDPSocketSendNoTag) {

        self.buffer = data
        self.timeout = timeout
        self.tag = tag

        self.resolveInProgress = false

    }
}

internal func ==(lhs: AsyncUDPSendPacket, rhs: AsyncUDPSendPacket) -> Bool {
    return lhs.buffer == rhs.buffer
}


/** 
 Extends UDPSocket

*/
internal extension AsyncUDPSocket {
    /**
     UPD sockt Flags.
     */
    internal struct UdpSocketFlags: ASOptionSet {
        internal let rawValue: Int
        internal init(rawValue: Int) { self.rawValue = rawValue }

        /** If set, the sockets have been created. */
        internal static let didCreateSockets: UdpSocketFlags        = UdpSocketFlags(rawValue: 1 << 0)
        internal static let didBind: UdpSocketFlags                 = UdpSocketFlags(rawValue: 1 << 1)
        internal static let connecting: UdpSocketFlags              = UdpSocketFlags(rawValue: 1 << 2)
        internal static let didConnect: UdpSocketFlags              = UdpSocketFlags(rawValue: 1 << 3)
        internal static let receiveOnce: UdpSocketFlags             = UdpSocketFlags(rawValue: 1 << 4)
        internal static let receiveContinous: UdpSocketFlags        = UdpSocketFlags(rawValue: 1 << 5)
        internal static let sendSourceSuspend: UdpSocketFlags       = UdpSocketFlags(rawValue: 1 << 6)
        internal static let recvSourceSuspend: UdpSocketFlags       = UdpSocketFlags(rawValue: 1 << 7)
        internal static let sockCanAccept: UdpSocketFlags           = UdpSocketFlags(rawValue: 1 << 8)
        internal static let forbidSendReceive: UdpSocketFlags       = UdpSocketFlags(rawValue: 1 << 9)
        internal static let closeAfterSend: UdpSocketFlags          = UdpSocketFlags(rawValue: 1 << 10)

    }

}


//MARK: - Binding
internal extension AsyncUDPSocket {

    /**
     PreCheck the requirements for Binding
    */
    internal func preBind() throws {

        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            throw BindErrors.unableToBind(msg: "Must be dispatched on Socket Queue")
        }

        guard addressFamily != AF_UNSPEC else {
            throw BindErrors.unknownInterface(msg: "Unknown Interface..")
        }

        guard flags.contains(.didBind) == false else {
            throw BindErrors.alreadyBound(msg: "Cannot bind a socket more than once.")
        }

        guard flags.contains([.connecting, .didConnect]) == false else {
            throw BindErrors.alreadyConnected(msg: "Cannot bind after connecting. If needed, bind first, then connect")
        }

    }

    internal func createInterface(_ interface: InterfaceType, port: UInt16, family: Int32) -> Data? {

        var interfaceData: Data?

        switch interface {

        case .ipAddress(let address):
            if family == AF_INET {
                var sockaddr: sockaddr_in = sockaddr_in()
                sockaddr.sin_len            = UInt8(sizeof(sockaddr_in))
                sockaddr.sin_family         = sa_family_t(AF_INET)
                sockaddr.sin_port           = port.bigEndian
                sockaddr.sin_addr.s_addr    = inet_addr(address)

                interfaceData = NSData(bytes: &sockaddr, length: sizeof(sockaddr_in)) as Data

            } else if family == AF_INET6 {
                var sockaddr: sockaddr_in6 = sockaddr_in6()
                sockaddr.sin6_len            = UInt8(sizeof(sockaddr_in6))
                sockaddr.sin6_family         = sa_family_t(AF_INET6)
                sockaddr.sin6_port           = port.bigEndian
                inet_pton(AF_INET6, address, &sockaddr.sin6_addr);

                interfaceData = NSData(bytes: &sockaddr, length: sizeof(sockaddr_in6)) as Data
            }

        case .anyAddrIPV4:
            var sockaddr: sockaddr_in   = sockaddr_in()
            sockaddr.sin_len            = UInt8(sizeof(sockaddr_in))
            sockaddr.sin_family         = sa_family_t(AF_INET)
            sockaddr.sin_port           = port.bigEndian
            sockaddr.sin_addr.s_addr    = INADDR_ANY.bigEndian  //INADDR_ANY

            interfaceData = NSData(bytes: &sockaddr, length: sizeof(sockaddr_in)) as Data

        case .anyAddrIPV6:
            var sockaddr: sockaddr_in6  = sockaddr_in6()
            sockaddr.sin6_len           = UInt8(sizeof(sockaddr_in6))
            sockaddr.sin6_family        = sa_family_t(AF_INET6)
            sockaddr.sin6_port          = port.bigEndian
            sockaddr.sin6_addr          = in6addr_any

            interfaceData = NSData(bytes: &sockaddr, length: sizeof(sockaddr_in6)) as Data

        case .loopbackIPV4:
            var sockaddr: sockaddr_in = sockaddr_in()
            sockaddr.sin_len            = UInt8(sizeof(sockaddr_in))
            sockaddr.sin_family         = sa_family_t(AF_INET)
            sockaddr.sin_port           = port.bigEndian
            sockaddr.sin_addr.s_addr    = INADDR_LOOPBACK.bigEndian

            interfaceData = NSData(bytes: &sockaddr, length: sizeof(sockaddr_in)) as Data

        case .loopbackIPV6:
            var sockaddr: sockaddr_in6  = sockaddr_in6()
            sockaddr.sin6_len           = UInt8(sizeof(sockaddr_in6))
            sockaddr.sin6_family        = sa_family_t(AF_INET6)
            sockaddr.sin6_port          = port.bigEndian
            sockaddr.sin6_addr          = in6addr_loopback

            interfaceData = NSData(bytes: &sockaddr, length: sizeof(sockaddr_in6)) as Data

        }

        return interfaceData
    }

    internal func boundInterface(_ interface: Data) throws {

        var status: Int32 = 0

        let size = interface.count

        if self.addressFamily == AF_INET {

            let sockPtr = unsafeBitCast((interface as NSData).bytes, to: UnsafePointer<sockaddr_in>.self)

            status = bind(sockfd, UnsafePointer<sockaddr>(sockPtr), socklen_t(size))

        } else if self.addressFamily == AF_INET6 {

            let sockPtr = unsafeBitCast((interface as NSData).bytes, to: UnsafePointer<sockaddr_in6>.self)

            status = bind(sockfd, UnsafePointer<sockaddr>(sockPtr), socklen_t(size))

        }

        if status == -1 {
            closeSocketError()

            throw BindErrors.unableToBind(msg: "Error in bind() function")
        }

        #if swift(>=3.0)
            _ = flags.insert(.didBind)
        #else
            flags.insert(.didBind)
        #endif

    }


    internal func setSocketNonBlocking(_ socket: Int32) -> Bool {

        var currentFlags = fcntl(CInt(socket), F_GETFL)

        if currentFlags < 0 {
            return false
        }

        currentFlags |= O_NONBLOCK

        if fcntl(CInt(socket), currentFlags) < 0 {
            return false
        }

        return true
    }

    internal func createSocket(_ family: Int32, options: BindOptions) throws {

        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            throw BindErrors.socketCreateError(msg: "Must be dispatched on Socket Queue")
        }

        guard flags.contains(.didCreateSockets) == false else {
            throw BindErrors.socketsCreated(msg: "Sockets have already been created")
        }


        sockfd = socket(family, ASSocketType.dataGram.value, 0)

        if sockfd == SOCKET_NULL {
            throw BindErrors.socketCreateError(msg: "Error in Socket() create")
        }

        var status: Int32 = 0

        //This comes in from our Network Bridge
        guard setSocketNonBlocking(sockfd) else {
            throw BindErrors.socketCreateError(msg: "Error enabling non-blocking IO on socket (fcntl)")
        }

        //Set the Socket Options

        var reuseAddr: UInt32 = 1
        status = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, UInt32(sizeof(socklen_t)))
        if status == -1 {
            close(sockfd)
            throw BindErrors.socketCreateError(msg: "Error enabling address reuse (setsockopt)")
        }

        if options.contains(BindOptions.reusePort) {
            var reusePort: UInt32 = 1
            status = setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT, &reusePort, UInt32(sizeof(socklen_t)))
            if status == -1 {
                close(sockfd)
                throw BindErrors.socketCreateError(msg: "Error enabling port reuse (setsockopt)")
            }
        }

        if options.contains(BindOptions.enableBroadcast) {
            var enableBroadcast: UInt32 = 1
            status = setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &enableBroadcast, UInt32(sizeof(socklen_t)))
            if status == -1 {
                close(sockfd)
                throw BindErrors.socketCreateError(msg: "Error enabling broadcast (setsockopt)")
            }
        }

        var noSigPipe: UInt32 = 1
        status = setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, UInt32(sizeof(socklen_t)))
        if status == -1 {
            close(sockfd)
            throw BindErrors.socketCreateError(msg: "Error disabling sigpipe (setsockopt)")
        }

        setupSendReceiveSources()

        #if swift(>=3.0)
            _ = flags.insert(.didCreateSockets)
        #else
            flags.insert(.didCreateSockets)
        #endif

    }

    private func setupSendReceiveSources() {

        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            return
        }

//
        guard let newSendSource: DispatchSourceWrite = DispatchSource.write(fileDescriptor: sockfd, queue: socketQueue) else {
            close(sockfd)
            return
        }

        guard let newReceiveSource: DispatchSourceRead = DispatchSource.read(fileDescriptor: sockfd, queue: socketQueue) else {
            close(sockfd)
            return
        }

        //Setup event handlers
        //Send Handler
        newSendSource.setEventHandler { () -> Void in

            #if swift(>=3.0)
                _ = self.flags.insert(.sockCanAccept)
            #else
                self.flags.insert(.sockCanAccept)
            #endif

            if self.currentSend == nil {

                self.suspendSendSource()

            } else if self.currentSend?.resolveInProgress == true {

                self.suspendSendSource()

            } else {
                self.doSend()
            }

        }

        //Receive Handler
        newReceiveSource.setEventHandler { () -> Void in

            self.socketBytesAvailable = newReceiveSource.data

            if self.socketBytesAvailable > 0 {
                self.doReceive()
            } else {
                self.doReceiveEOF()
            }

        }

        //Cancel Handlers
        var socketFDRefCount: Int = 2
        let theSockFd = sockfd

        newSendSource.setCancelHandler { () -> Void in
            socketFDRefCount -= 1

            if socketFDRefCount == 0 {
                close(theSockFd)
            }
        }

        newReceiveSource.setCancelHandler { () -> Void in
            socketFDRefCount -= 1

            if socketFDRefCount == 0 {
                close(theSockFd)
            }
        }

        socketBytesAvailable = 0

        #if swift(>=3.0)
            _ = flags.insert([.sockCanAccept, .sendSourceSuspend, .recvSourceSuspend])
        #else
            flags.insert([.sockCanAccept, .sendSourceSuspend, .recvSourceSuspend])
        #endif

        sendSource = newSendSource
        receiveSource = newReceiveSource
    }

}

//MARK: - Close
internal extension AsyncUDPSocket {


    internal func closeSocketError(_ error: ASErrorType? = nil) {

        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            return
        }

        //Clean up send Queue

        let shouldCallDelegate: Bool = flags.contains(.didCreateSockets).boolValue ? true : false


        if shouldCallDelegate {
            //notify close!
            for observer in observers {
                //Observer decides which queue it will send back on
                observer.sockDidClose(self, error: error)
            }
        }

        closeSocketFinal()

        flags.remove(.didCreateSockets)

        flags = UdpSocketFlags()

    }

    internal func closeSocketFinal() {

        if sockfd != SOCKET_NULL {

            if let sSource = sendSource,
            let rSource = receiveSource {
                sSource.cancel()

                rSource.cancel()

                //Make sure they are not paused...
                resumeSendSource()
                resumeReceive()

                sockfd = SOCKET_NULL

                //clear States
                socketBytesAvailable = 0
                flags.remove(.sockCanAccept)

            }


        }

    }
}
