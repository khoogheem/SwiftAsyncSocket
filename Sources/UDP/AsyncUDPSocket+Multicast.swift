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

                if self.addressFamily == AF_INET {
                    #if swift(>=3.0)
                        try self.performMulticast(request: IP_ADD_MEMBERSHIP, forGroup: group, onInterface: _interface)
                    #else
                        try self.performMulticast(IP_ADD_MEMBERSHIP, forGroup: group, onInterface: _interface)
                    #endif

                } else {
                    #if swift(>=3.0)
                        try self.performMulticast(request: IPV6_JOIN_GROUP, forGroup: group, onInterface: _interface)
                    #else
                        try self.performMulticast(IPV6_JOIN_GROUP, forGroup: group, onInterface: _interface)
                    #endif

                }

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

//        ASLog("Joined Multicast Group %@", group)

    }

    public func leaveMulticast(group: String, interface _interface: String = "anyaddr") throws {
        var errorCode: MulticastErrors?

        let block: dispatch_block_t = {

            do {
                if self.addressFamily == AF_INET {
                    #if swift(>=3.0)
                        try self.performMulticast(request: IP_DROP_MEMBERSHIP, forGroup: group, onInterface: _interface)
                    #else
                        try self.performMulticast(IP_DROP_MEMBERSHIP, forGroup: group, onInterface: _interface)
                    #endif

                } else {
                    #if swift(>=3.0)
                        try self.performMulticast(request: IPV6_LEAVE_GROUP, forGroup: group, onInterface: _interface)
                    #else
                        try self.performMulticast(IPV6_LEAVE_GROUP, forGroup: group, onInterface: _interface)
                    #endif

                }

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

//        ASLog("Leaving Multicast Group %@", group)

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
            ASLog("Error: \(error)")
            throw error
        }

        #if swift(>=3.0)
            let group = (forGroup as NSString).utf8String
        #else
            let group = (forGroup as NSString).UTF8String
        #endif

        #if swift(>=3.0)
            let groupFamily: Int32 = forGroup.components(separatedBy: ":").count > 1 ? AF_INET6 : AF_INET
        #else
            let groupFamily: Int32 = forGroup.characters.split(":").count > 1 ? AF_INET6 : AF_INET
        #endif


        #if swift(>=3.0)
            let groupPtr = unsafeBitCast(group, to: UnsafePointer<Int8>.self)
        #else
            let groupPtr = unsafeBitCast(group, UnsafePointer<Int8>.self)
        #endif

        #if swift(>=3.0)
            var groupAddr: UnsafeMutablePointer<addrinfo>? = UnsafeMutablePointer<addrinfo>(allocatingCapacity: 1)
        #else
            var groupAddr: UnsafeMutablePointer<addrinfo> = UnsafeMutablePointer<addrinfo>(nil)
        #endif


        var hints = addrinfo(
            ai_flags: AI_NUMERICHOST,   //no name resolution
            ai_family: groupFamily,
            ai_socktype: ASSocketType.DataGram.value,
            ai_protocol: ASIPProto.UDP.value,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)


        #if swift(>=3.0)

            if getaddrinfo(UnsafePointer<Int8>(groupPtr), UnsafePointer<Int8>(bitPattern: 0), &hints, &groupAddr) != 0 {
                throw MulticastErrors.JoinError(msg: "Unknown group. Specify valid group IP address")
            }
        #else
            if getaddrinfo(UnsafePointer<Int8>(groupPtr), UnsafePointer<Int8>(bitPattern: 0), &hints, &groupAddr) != 0 {
            throw MulticastErrors.JoinError(msg: "Unknown group. Specify valid group IP address")
            }
        #endif


        #if swift(>=3.0)
            print("--group: \(groupAddr?.pointee)")
        #else
            print("--group: \(groupAddr.memory)")
        #endif


        //Perform Request
        if sockfd != SOCKET_NULL {
            #if swift(>=3.0)
                let interfaceData = self.createInterface(interfaceName: onInterface, port: 0, family: addressFamily)
            #else
                let interfaceData = self.createInterface(onInterface, port: 0, family: addressFamily)
            #endif


            if interfaceData != nil {
                #if swift(>=3.0)
                    let interfaceAddr = unsafeBitCast(interfaceData!.bytes, to: UnsafePointer<sockaddr_in>.self)
                #else
                    let interfaceAddr = unsafeBitCast(interfaceData!.bytes, UnsafePointer<sockaddr_in>.self)
                #endif


                //print("--interfaceAddr: \(interfaceAddr.memory)")
                #if swift(>=3.0)
                    if Int32(interfaceAddr.pointee.sin_family) != groupAddr?.pointee.ai_family {
                        throw MulticastErrors.JoinError(msg: "Multicast Error: Socket, group, and interface do not have matching IP versions")
                    }

                    if doMulticastJoinLeave(request: request, groupAddr: groupAddr!, interfaceAddr: interfaceAddr) != 0 {
                        throw MulticastErrors.JoinError(msg: "Error in setsockopt() function")
                    }

                    groupAddr?.deinitialize()
                    groupAddr?.deallocateCapacity(1)
                #else
                    if Int32(interfaceAddr.memory.sin_family) != groupAddr.memory.ai_family {
                    throw MulticastErrors.JoinError(msg: "Multicast Error: Socket, group, and interface do not have matching IP versions")
                    }

                    if doMulticastJoinLeave(request, groupAddr: groupAddr, interfaceAddr: interfaceAddr) != 0 {
                    throw MulticastErrors.JoinError(msg: "Error in setsockopt() function")
                    }

                    groupAddr.destroy()
                    groupAddr.dealloc(1)
                #endif



            } else {
                //This should Never happen.. as we should have bailed already!
                throw MulticastErrors.JoinError(msg: "Unknown interface. Must Bind to Socket First")
            }

        } else {

        }

    }

    private func doMulticastJoinLeave(request: Int32, groupAddr: UnsafeMutablePointer<addrinfo>, interfaceAddr: UnsafePointer<sockaddr_in>) -> Int32 {

        //Do actual Multicast Join/Leave
        var status: Int32 = 0

        if self.addressFamily == AF_INET {
            var imReq: ip_mreq = ip_mreq()
            #if swift(>=3.0)
                let nativeGroup = unsafeBitCast(groupAddr.pointee.ai_addr, to: UnsafePointer<sockaddr_in>.self)

                imReq.imr_multiaddr = nativeGroup.pointee.sin_addr
                imReq.imr_interface = interfaceAddr.pointee.sin_addr

            #else
                let nativeGroup = unsafeBitCast(groupAddr.memory.ai_addr, UnsafePointer<sockaddr_in>.self)

                imReq.imr_multiaddr = nativeGroup.memory.sin_addr
                imReq.imr_interface = interfaceAddr.memory.sin_addr

            #endif

            status = setsockopt(sockfd, ASIPProto.IPV4.value, request, &imReq, UInt32(sizeof(ip_mreq)))

        } else if self.addressFamily == AF_INET6 {
            var imReq: ipv6_mreq = ipv6_mreq()

            #if swift(>=3.0)
                let nativeGroup = unsafeBitCast(groupAddr.pointee.ai_addr, to: UnsafePointer<sockaddr_in6>.self)

                imReq.ipv6mr_multiaddr = nativeGroup.pointee.sin6_addr
                imReq.ipv6mr_interface = UInt32(interfaceAddr.pointee.sin_addr.s_addr)

            #else
                let nativeGroup = unsafeBitCast(groupAddr.memory.ai_addr, UnsafePointer<sockaddr_in6>.self)

                imReq.ipv6mr_multiaddr = nativeGroup.memory.sin6_addr
                imReq.ipv6mr_interface = UInt32(interfaceAddr.memory.sin_addr.s_addr)

            #endif

            status = setsockopt(sockfd, ASIPProto.IPV6.value, request, &imReq, UInt32(sizeof(ipv6_mreq)))
        }

        return status
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