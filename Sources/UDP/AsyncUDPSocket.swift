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
import Darwin

let INADDR_LOOPBACK = UInt32(0x7f000001)
let INADDR_ANY = UInt32(0x00000000)


public class AsyncUDPSocket {

    //Public
    public enum BindErrors: ErrorType {
        case AlreadyBound(msg: String)
        case AlreadyConnected(msg: String)
        case UnknownInterface(msg: String)
        case UnableToBind(msg: String)
        case SocketsCreated(msg: String)
        case SocketCreateError(msg: String)
    }

    public enum MulticastErrors: ErrorType {
        case JoinError(msg: String)
    }

    public enum SendReceiveErrors: ErrorType {
        case AlreadyReceiving(msg: String)
        case NotBound(msg: String)
        case ResolveIssue(msg: String)
        case SendIssue(msg: String)
        case SendTimout(msg: String)
    }

    public enum SocketCloseErrors: ErrorType {
        case Error(msg: String)
    }

    /**
     Socket Bind Options
    */
    public struct BindOptions: OptionSetType {
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

    internal var socketQueue: dispatch_queue_t

    internal var sockfd: Int32

    internal var sendSource: dispatch_source_t?
    
    internal var receiveSource: dispatch_source_t?

    internal var sendTimer: dispatch_source_t?

    internal let dispatchQueueKey = "UPDSocketQueue"

    static var udpQueueIDKey = unsafeBitCast(AsyncUDPSocket.self, UnsafePointer<Void>.self)     // some unique pointer
    private lazy var udpQueueID: UnsafeMutablePointer<Void> = { [unowned self] in
        unsafeBitCast(self, UnsafeMutablePointer<Void>.self)   // pointer to self
    }()

    public init() {

        self.flags = UdpSocketFlags()

        self.sockfd = 0
        self.socketBytesAvailable = 0

        self.addressFamily = AF_UNSPEC

        self.currentSend = nil

        socketQueue = dispatch_queue_create("UPDSocketQueue", DISPATCH_QUEUE_SERIAL)

        dispatch_queue_set_specific(socketQueue, AsyncUDPSocket.udpQueueIDKey, udpQueueID, nil)

    }


    deinit {

        dispatch_sync(socketQueue) { () -> Void in
            self.closeSocketError()
        }
    }

    internal var isCurrentQueue: Bool {
        return dispatch_get_specific(AsyncUDPSocket.udpQueueIDKey) == udpQueueID
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

//MARK: - Observer {
public extension AsyncUDPSocket {

    /**
     Add Observer to the AsyncUDPSocket
     
     - parameter observer: AsyncUDPSocketObserver object
    */
    public func addObserver(observer: AsyncUDPSocketObserver) {

        self.observers.append(observer)

    }

    public func removeObserver(observer: AsyncUDPSocketObserver) {

        for (idx, obsvr) in observers.enumerate() {
            if obsvr == observer {
                observers.removeAtIndex(idx)
            }
        }
    }
}

//MARK: - Binding
public extension AsyncUDPSocket {

    /**
     close the Socket
    */
    public func closeSocket() {

        let block: dispatch_block_t = {

            self.closeSocketError()
        }

        dispatch_sync(socketQueue, block)
    }

    /**
     Close the Socket only after all Send Requests have been performed
    */
    public func closeSocketAfterSend() {

        let block: dispatch_block_t = {

            self.flags.insert(.closeAfterSend)

            if self.currentSend == nil && self.sendQueue.count == 0 {
                self.closeSocketError(SocketCloseErrors.Error(msg: "Closing with nothing more to Send"))
            }
        }

        dispatch_sync(socketQueue, block)
    }

    /**
     Binds to a Interface and Port
     
     Interface can be:
     
        - anyaddr - Binds to all Interfaces for the Specific Port
        - localhost or loopback - Binds to localhost only
        - IP Address - A specific IP Address
    */
    public func bindTo(port: UInt16, interface _interface: String = "anyaddr", option: BindOptions = [.reusePort]) throws {

        var errorCode: BindErrors?

        let block: dispatch_block_t = {
            self.addressFamily = _interface.characters.split(":").count > 1 ? AF_INET6 : AF_INET

            do {
                try self.preBind()

            } catch {
                NSLog("Error: \(error)")
                errorCode = (error as? BindErrors)!
                return
            }

            let interfaceData = self.createInterface(_interface, port: port, family: self.addressFamily)

            if interfaceData == nil {
                let error = BindErrors.UnknownInterface(msg: "Unknown interface. Specify valid interface by name (e.g. 'anyaddr', 'en0') or IP address.")
                NSLog("Error: \(error)")
                errorCode = error
                return
            }

            do {
                try self.createSocket(self.addressFamily, options: option)
            } catch{
                print(error)
                errorCode = (error as? BindErrors)!
                return
            }

            do {
                try self.boundInterface(interfaceData!)

            } catch {
//                NSLog("Error: \(error)")
                errorCode = (error as? BindErrors)!
                return
            }
            
        }

        if isCurrentQueue == true {
            block()
        }else {
            dispatch_sync(socketQueue, block)
        }

        if let error = errorCode {
            throw error
        }

    }
}
