//
//  AsyncUDPSocket.swift
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

let INADDR_LOOPBACK = UInt32(0x7f000001)
let INADDR_ANY = UInt32(0x00000000)


public class AsyncUDPSocket {

    //Public
    public enum BindErrors: ASErrorType {
        case alreadyBound(msg: String)
        case alreadyConnected(msg: String)
        case unknownInterface(msg: String)
        case unableToBind(msg: String)
        case socketsCreated(msg: String)
        case socketCreateError(msg: String)
    }

    public enum MulticastErrors: ASErrorType {
        case joinError(msg: String)
    }

    public enum SendReceiveErrors: ASErrorType {
        case alreadyReceiving(msg: String)
        case notBound(msg: String)
        case resolveIssue(msg: String)
        case sendIssue(msg: String)
        case sendTimout(msg: String)
    }

    public enum SocketCloseErrors: ASErrorType {
        case error(msg: String)
    }

    /**
     Socket Bind Options
    */
    public struct BindOptions: ASOptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /** Reuse Port */
        public static let reusePort: BindOptions        = BindOptions(rawValue: 1 << 0)
        /** Enable Broadcast Messages on Socket */
        public static let enableBroadcast: BindOptions  = BindOptions(rawValue: 1 << 1)

    }

    internal(set) public var addressFamily: Int32
    private(set) var observers = [AsyncUDPSocketObserver]()


    //Internal
    //Max Buffer size for Packets
    internal let maxReceiveSize: Int = 9126
    internal var currentSend: AsyncUDPSendPacket?
    internal var sendQueue: [AsyncUDPSendPacket] = []

    internal var flags: UdpSocketFlags
    internal let SOCKET_NULL: Int32 = -1
    internal var socketBytesAvailable: UInt

    //sock

    internal var socketQueue: DispatchQueue

    internal var sockfd: Int32

    internal var sendSource: DispatchSourceWrite?
    
    internal var receiveSource: DispatchSourceRead?

    internal var sendTimer: DispatchSourceTimer?

    internal let dispatchQueueKey = "UDPSocketQueue"

//    static var udpQueueIDKey = unsafeBitCast(AsyncUDPSocket.self, to: UnsafePointer<Void>.self)     // some unique pointer
    static var udpQueueIDKey: DispatchSpecificKey<UnsafeMutablePointer<Void>> = DispatchSpecificKey()

    private lazy var udpQueueID: UnsafeMutablePointer<Void> = { [unowned self] in
        unsafeBitCast(self, to: UnsafeMutablePointer<Void>.self)   // pointer to self
    }()

    public init() {

        self.flags = UdpSocketFlags()

        self.sockfd = 0
        self.socketBytesAvailable = 0

        self.addressFamily = AF_UNSPEC

        self.currentSend = nil

        socketQueue = DispatchQueue(label: dispatchQueueKey, attributes: DispatchQueueAttributes.serial)

        socketQueue.setSpecific(key: AsyncUDPSocket.udpQueueIDKey, value: udpQueueID)

    }


    deinit {

        socketQueue.sync { () -> Void in
            self.closeSocketError()
        }
    }

    internal var isCurrentQueue: Bool {
        return DispatchQueue.getSpecific(key: AsyncUDPSocket.udpQueueIDKey) == udpQueueID
    }

}

public func ==(lhs: AsyncUDPSocket.BindErrors, rhs: AsyncUDPSocket.BindErrors) -> Bool {
    return lhs._code == rhs._code
}

public func !=(lhs: AsyncUDPSocket.BindErrors, rhs: AsyncUDPSocket.BindErrors) -> Bool {
    return lhs._code != rhs._code
}

public func !=(lhs: AsyncUDPSocket.MulticastErrors, rhs: AsyncUDPSocket.MulticastErrors) -> Bool {
    return lhs._code != rhs._code
}

public func !=(lhs: AsyncUDPSocket.SendReceiveErrors, rhs: AsyncUDPSocket.SendReceiveErrors) -> Bool {
    return lhs._code != rhs._code
}

//MARK: - Observer
public extension AsyncUDPSocket {

    /**
     Add Observer to the AsyncUDPSocket
     
     - parameter observer: AsyncUDPSocketObserver object
    */
    public func addObserver(_ observer: AsyncUDPSocketObserver) {

        self.observers.append(observer)

    }

    public func removeObserver(_ observer: AsyncUDPSocketObserver) {

        #if swift(>=3.0)
            for (idx, obsvr) in observers.enumerated() {
                if obsvr == observer {
                    observers.remove(at: idx)
                }
            }
        #else
            for (idx, obsvr) in observers.enumerated() {
                if obsvr == observer {
                    observers.remove(at: idx)
                }
            }
        #endif

    }
}

//MARK: - Binding
public extension AsyncUDPSocket {

    /**
     close the Socket
    */
    public func closeSocket() {


        let block: as_dispatch_block_t = {

            self.closeSocketError()
        }

        socketQueue.sync(execute: block)
    }

    /**
     Close the Socket only after all Send Requests have been performed
    */
    public func closeSocketAfterSend() {

        let block: as_dispatch_block_t = {

            #if swift(>=3.0)
                _ = self.flags.insert(.closeAfterSend)
            #else
                self.flags.insert(.closeAfterSend)
            #endif

            if self.currentSend == nil && self.sendQueue.count == 0 {
                self.closeSocketError(SocketCloseErrors.error(msg: "Closing with nothing more to Send"))
            }
        }

        socketQueue.sync(execute: block)
    }


    /**
     Binds to a Interface and Port
     
     Interface can be:
     
        - anyaddr - Binds to all Interfaces for the Specific Port
        - localhost or loopback - Binds to localhost only
        - IP Address - A specific IP Address
    */
    public func bindTo(port: UInt16, interface _interface: InterfaceType = InterfaceType.anyAddrIPV4, option: BindOptions = [.reusePort]) throws {
//    public func bindTo(port: UInt16, interface _interface: String = "anyaddr", option: BindOptions = [.reusePort]) throws {

        var errorCode: BindErrors?

        let block: as_dispatch_block_t = {
            self.addressFamily = self.determineAFType(interface: _interface)

            do {
                try self.preBind()

            } catch {
                ASLog("Error: \(error)")
                errorCode = (error as? BindErrors)!
                return
            }

            let interfaceData = self.createInterface(_interface, port: port, family: self.addressFamily)

            if interfaceData == nil {
                let error = BindErrors.unknownInterface(msg: "Unknown interface. Specify valid interface by name (e.g. 'anyaddr', 'en0') or IP address.")
                ASLog("Error: \(error)")
                errorCode = error
                return
            }

            do {
                try self.createSocket(self.addressFamily, options: option)

            } catch{
                ASLog("Error: \(error)")
                errorCode = (error as? BindErrors)!
                return
            }

            do {
                try self.boundInterface(interfaceData!)

            } catch {
                ASLog("Error: \(error)")
                errorCode = (error as? BindErrors)!
                return
            }
            
        }

        if isCurrentQueue == true {
            block()
        }else {
            socketQueue.sync(execute: block)
        }

        if let error = errorCode {
            throw error
        }

    }
}

private extension AsyncUDPSocket {

    /**
     Gets the Correct Family Type for the Interface passed in.
     
     - returns: Int32 Value for Family type
    */
    private func determineAFType(interface: InterfaceType) -> Int32 {
        switch interface {
        case .ipAddress(let address):
            return address.characters.split(separator: ":").count > 1 ? AF_INET6 : AF_INET
        case .anyAddrIPV4:
            return AF_INET
        case .anyAddrIPV6:
            return AF_INET6
        case .loopbackIPV4:
            return AF_INET
        case .loopbackIPV6:
            return AF_INET6
        }
    }

}
