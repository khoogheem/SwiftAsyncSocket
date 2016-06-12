//
//  Shims.swift
//  SwiftAsyncSocket
//
//  Created by Kevin Hoogheem on 6/9/16.
//  Copyright © 2016 Kevin A. Hoogheem. All rights reserved.
//

import Foundation


#if swift(>=3.0)
    public typealias ASErrorType = ErrorProtocol
#else
    public typealias ASErrorType = ErrorType
#endif

#if swift(>=3.0)
    public typealias ASOptionSet = OptionSet
#else
    public typealias ASOptionSet = OptionSetType
#endif

public enum ASSocketType {
    case Stream
    case DataGram

    public var value: Int32  {

        switch self {
        case Stream:
            #if os(Linux)
                return Int32(SOCK_STREAM.rawValue)
            #else
                return SOCK_STREAM
            #endif
        case DataGram:
            #if os(Linux)
                return Int32(SOCK_DGRAM.rawValue)
            #else
                return SOCK_DGRAM
            #endif

        }
    }

}

public enum ASIPProto {
    case IPV4
    case IPV6
    case UDP

    public var value: Int32  {

        switch self {
        case IPV4:
            #if os(Linux)
                return Int32(IPPROTO_IP)
            #else
                return IPPROTO_IP
            #endif

        case IPV6:
            #if os(Linux)
                return Int32(IPPROTO_IPV6)
            #else
                return IPPROTO_IPV6
            #endif

        case UDP:
            #if os(Linux)
                return Int32(IPPROTO_UDP)
            #else
                return IPPROTO_UDP
            #endif

        }
    }
}

