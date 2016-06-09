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

