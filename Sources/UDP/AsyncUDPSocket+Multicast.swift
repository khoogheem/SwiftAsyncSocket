//
//  AsyncUDPSocket+Multicast.swift
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

//MARK: - Multicast
public extension AsyncUDPSocket {

    public func joinMulticast(group: String, interface _interface: String = "anyaddr") throws {
        var errorCode: MulticastErrors?

        let block: dispatch_block_t = {

            do {
                try self.performMulticast(IP_ADD_MEMBERSHIP, forGroup: group, onInterface: _interface)
            } catch{
                print(error)
                errorCode = (error as? MulticastErrors)!
                return
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

//        NSLog("Joined Multicast Group %@", group)

    }

    public func leaveMulticast(group: String, interface _interface: String = "anyaddr") throws {
        var errorCode: MulticastErrors?

        let block: dispatch_block_t = {

            do {
                try self.performMulticast(IP_DROP_MEMBERSHIP, forGroup: group, onInterface: _interface)
            } catch{
                print(error)
                errorCode = (error as? MulticastErrors)!
                return
            }

        }

        dispatch_sync(socketQueue, block)

        if let errors = errorCode {
            throw errors
        }

//        NSLog("Leaving Multicast Group %@", group)

    }
    
}

/** 
 Multicast Extends AsyncUDPSocket

*/
internal extension AsyncUDPSocket {


    internal func performMulticast(request: Int32, forGroup: String, onInterface: String) throws {

        do {
            try self.preCheck()

        } catch {
            NSLog("Error: \(error)")
            throw error
        }

        let group = (forGroup as NSString).UTF8String
        let groupFaimly: Int32 = forGroup.characters.split(":").count > 1 ? AF_INET6 : AF_INET

        let groupPtr = unsafeBitCast(group, UnsafePointer<Int8>.self)

        var groupAddr: UnsafeMutablePointer<addrinfo> = UnsafeMutablePointer<addrinfo>(nil)

        var hints = addrinfo(
            ai_flags: AI_NUMERICHOST,   //no name resolution
            ai_family: groupFaimly,
            ai_socktype: SOCK_DGRAM,
            ai_protocol: IPPROTO_UDP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)

        if getaddrinfo(UnsafePointer<Int8>(groupPtr), UnsafePointer<Int8>(bitPattern: 0), &hints, &groupAddr) != 0 {
            throw MulticastErrors.JoinError(msg: "Unknown group. Specify valid group IP address")
        }

        //print("--group: \(groupAddr.memory)")

        //Perform Request
        if sockfd != SOCKET_NULL {
            let interfaceData = self.createInterface(onInterface, port: 0, family: addressFamily)

            if interfaceData != nil {
                let interfaceAddr = unsafeBitCast(interfaceData!.bytes, UnsafePointer<sockaddr_in>.self)

                //print("--interfaceAddr: \(interfaceAddr.memory)")

                if Int32(interfaceAddr.memory.sin_family) != groupAddr.memory.ai_family {
                    throw MulticastErrors.JoinError(msg: "Multicast Error: Socket, group, and interface do not have matching IP versions")
                }

                //Do actual Multicast Join/Leave
                var imReq: ip_mreq = ip_mreq()
                let nativeGroup = unsafeBitCast(groupAddr.memory.ai_addr, UnsafePointer<sockaddr_in>.self)

                imReq.imr_multiaddr = nativeGroup.memory.sin_addr
                imReq.imr_interface = interfaceAddr.memory.sin_addr

                var status: Int32 = 0
                let proto: Int32 = addressFamily == AF_INET ? IPPROTO_IP : IPPROTO_IPV6

                status = setsockopt(sockfd, proto, request, &imReq, UInt32(sizeof(ip_mreq)))
                if status != 0 {
                    throw MulticastErrors.JoinError(msg: "Error in setsockopt() function")
                }

                groupAddr.destroy()
                groupAddr.dealloc(1)


            } else {
                //This should Never happen.. as we should have bailed already!
                throw MulticastErrors.JoinError(msg: "Unknown interface. Must Bind to Socket First")
            }

        } else {

        }

    }

}


private extension AsyncUDPSocket {

    /**
     PreCheck the requirements for Multicast
     */
    private func preCheck() throws {

        guard flags.contains(.didBind) == true else {
            throw BindErrors.AlreadyBound(msg: "Must bind a socket before joining a multicast group.")
        }

        guard flags.contains([.connecting, .didConnect]) == false else {
            throw BindErrors.AlreadyConnected(msg: "Cannot join a multicast group if connected")
        }
        
    }

}