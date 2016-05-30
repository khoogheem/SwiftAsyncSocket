//
//  UDPReceiveObserver.swift
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

/** 
 UDPReceiveObserver Struct

*/
public struct UDPReceiveObserver: AsyncUDPSocketObserver {

    private let receiveHandler: ((AsyncUDPSocket, NSData, String, UInt16) -> Void)?
    private let closeHandler: ((socket: AsyncUDPSocket, error: ErrorType?) -> Void)?
    private let dispatchQueue: dispatch_queue_t

    private(set) public var uuid: NSUUID

    public init(
        closeHandler: ((socket: AsyncUDPSocket, error: ErrorType?) -> Void)? = nil,
        receiveHandler: ((socket: AsyncUDPSocket, data: NSData, fromHost: String, onPort: UInt16) -> Void)? = nil,
        onQueue: dispatch_queue_t = dispatch_get_main_queue()
        ){
            self.closeHandler = closeHandler
            self.receiveHandler = receiveHandler
            self.dispatchQueue = onQueue
            self.uuid = NSUUID()
    }
    //MARK: - Observers

    public func sockDidClose(socket: AsyncUDPSocket, error: ErrorType?) {
        dispatch_async(dispatchQueue) { () -> Void in
            self.closeHandler?(socket: socket, error: error)
        }
    }

    public func socketDidReceive(socket: AsyncUDPSocket, data: NSData, fromHost: String, onPort: UInt16) {

        dispatch_async(dispatchQueue) { () -> Void in
            self.receiveHandler?(socket, data, fromHost, onPort)
        }
    }

    public func socketDidNotSend(socket: AsyncUDPSocket, tag: Int, error: AsyncUDPSocket.SendReceiveErrors) {
        //No Op
    }

    public func socketDidSend(socket: AsyncUDPSocket, tag: Int) {
        //no Op
    }
}
