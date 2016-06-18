//
//  Shims.swift
//  SwiftAsyncSocket
//
//  Created by Kevin Hoogheem on 6/9/16.
//  Copyright © 2016 Kevin A. Hoogheem. All rights reserved.
//

import Foundation


public typealias as_dispatch_block_t = (Void)->Void

public typealias ASErrorType = ErrorProtocol
public typealias ASOptionSet = OptionSet

public enum ASSocketType {
    case stream
    case dataGram

    public var value: Int32  {

        switch self {
        case stream:
            #if os(Linux)
                return Int32(SOCK_STREAM.rawValue)
            #else
                return SOCK_STREAM
            #endif
        case dataGram:
            #if os(Linux)
                return Int32(SOCK_DGRAM.rawValue)
            #else
                return SOCK_DGRAM
            #endif

        }
    }

}

public enum ASIPProto {
    case ipv4
    case ipv6
    case udp

    public var value: Int32  {

        switch self {
        case ipv4:
            #if os(Linux)
                return Int32(IPPROTO_IP)
            #else
                return IPPROTO_IP
            #endif

        case ipv6:
            #if os(Linux)
                return Int32(IPPROTO_IPV6)
            #else
                return IPPROTO_IPV6
            #endif

        case udp:
            #if os(Linux)
                return Int32(IPPROTO_UDP)
            #else
                return IPPROTO_UDP
            #endif

        }
    }
}

