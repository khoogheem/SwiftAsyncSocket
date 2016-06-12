//
//  AsyncUDPSocketObserver.swift
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
 AsyncUDPSocketObserver protocol

*/
public protocol AsyncUDPSocketObserver {

    var uuid: NSUUID { get }

    func socketDidReceive(socket: AsyncUDPSocket, data: NSData, fromHost: String, onPort: UInt16)

    func sockDidClose(socket: AsyncUDPSocket, error: ASErrorType?)


    //Send Errors
    func socketDidNotSend(socket: AsyncUDPSocket, tag: Int, error: AsyncUDPSocket.SendReceiveErrors)

    func socketDidSend(socket: AsyncUDPSocket, tag: Int)

}

public func ==(lhs: AsyncUDPSocketObserver, rhs: AsyncUDPSocketObserver) -> Bool {
    #if swift(>=3.0)
        #if os(Linux)
            return lhs.uuid.UUIDString == rhs.uuid.UUIDString
        #else
            return lhs.uuid.uuidString == rhs.uuid.uuidString
        #endif
    #else
        return lhs.uuid.UUIDString == rhs.uuid.UUIDString
    #endif
}


//public func ==<T :AsyncUDPSocketObserver> (lhs: T, rhs: T) -> Bool {
//    return lhs.uuid.UUIDString == rhs.uuid.UUIDString
//}

extension AsyncUDPSocketObserver {

    public var hashValue: Int {
        get {
            #if swift(>=3.0)
                #if os(Linux)
                    return uuid.UUIDString.hashValue
                #else
                    return uuid.uuidString.hashValue
                #endif
            #else
                return uuid.UUIDString.hashValue
            #endif

        }
    }
}
