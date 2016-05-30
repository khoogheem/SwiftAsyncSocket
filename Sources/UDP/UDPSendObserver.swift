//
//  UDPSendObserver.swift
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

/** UDPSendObserver Struct

*/
public struct UDPSendObserver: AsyncUDPSocketObserver {

    private let didSendHandler: ((socket: AsyncUDPSocket, tag: Int) -> Void)?
    private let didNotSendHandler: ((socket: AsyncUDPSocket, tag: Int, error: AsyncUDPSocket.SendReceiveErrors) -> Void)?
    private let dispatchQueue: dispatch_queue_t

    private(set) public var uuid: NSUUID

    public init(
        didSend: ((socket: AsyncUDPSocket, tag: Int) -> Void)? = nil,
        didNotSend: ((socket: AsyncUDPSocket, tag: Int, error: AsyncUDPSocket.SendReceiveErrors) -> Void)? = nil,
        onQueue: dispatch_queue_t = dispatch_get_main_queue()
        ) {

            self.didSendHandler = didSend
            self.didNotSendHandler = didNotSend
            self.dispatchQueue = onQueue

            self.uuid = NSUUID()
    }
    //MARK: - Observers

    public func sockDidClose(socket: AsyncUDPSocket, error: ErrorType?) {
        //No Op
    }

    public func socketDidReceive(socket: AsyncUDPSocket, data: NSData, fromHost: String, onPort: UInt16) {
        //No Op
    }

    public func socketDidNotSend(socket: AsyncUDPSocket, tag: Int, error: AsyncUDPSocket.SendReceiveErrors) {
        dispatch_async(dispatchQueue) { () -> Void in
            self.didNotSendHandler?(socket: socket, tag: tag, error: error)
        }
    }

    public func socketDidSend(socket: AsyncUDPSocket, tag: Int) {
        dispatch_async(dispatchQueue) { () -> Void in
            self.didSendHandler?(socket: socket, tag: tag)
        }
    }
}
