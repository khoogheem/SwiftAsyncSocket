//
//  SwiftAsyncSocketTests.swift
//  SwiftAsyncSocketTests
//
//  Created by Kevin Hoogheem on 12/10/15.
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

import XCTest
@testable import SwiftAsyncSocket

public extension NSMutableData {

    /**
     Appends a byte to NSMutableData

     - parameter byte: A Byte to append to the NSMutableData
     */
    public func appendByte(byte: UInt8) {
        var sendByte = byte

        self.appendBytes(&sendByte, length: 1)
    }
    
}

/**
 Extension Extends String

 */
extension String {

    var hexaToInt		: Int		{ return Int(strtoul(self, nil, 16))    }
    var hexaToDouble	: Double	{ return Double(strtoul(self, nil, 16)) }
    var hexaToBinary	: String	{ return String(hexaToInt, radix: 2)    }
    //    var intToHexa		: String	{ return String(toInt(), radix: 16)    }
    //    var intToBinary		: String	{ return String(toInt(), radix: 2)     }
    var binaryToInt		: Int		{ return Int(strtoul(self, nil, 2))     }
    var binaryToDouble	: Double	{ return Double(strtoul(self, nil, 2))  }
    var binaryToHexa	: String	{ return String(binaryToInt, radix: 16) }
    var toBtyes			: [UInt8]	{ return [UInt8](self.utf8)             }
    //    var toBtye			: UInt8		{ return UInt8(strtoul(self, nil, 1))	}
    //    var toByte          : UInt8     { return UInt8(ascii: UnicodeScalar(self)) }
    var toBtye          : UInt8     {return [UInt8](self.utf8)[0] } //I don't like but works for now
    var floatValue		: Float		{ return (self as NSString).floatValue  }
    
}
internal let DEFAULT_LISTEN_PORT: UInt16 = 17653


class SwiftAsyncSocketTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    
    func testExample() {

        let expectation: XCTestExpectation = expectationWithDescription("test")

        let waspMsg = NSMutableData()

        waspMsg.appendByte("A".toBtye)
        waspMsg.appendByte("N".toBtye)
        waspMsg.appendByte(0x46)
        waspMsg.appendByte(0)
        waspMsg.appendByte(0)
        waspMsg.appendByte(0xFF)

        var count = 0

        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        let observ = UDPReceiveObserver(closeHandler: { thesock, error -> Void in

            NSLog("Socket did Close: \(error)")

            }, receiveHandler: { (theSocket, data, host, port) -> Void in

                print("\n Data: \(data) from: \(host) onPort:\(port)")

                if count == 5 {
                   // UDP.send(waspMsg, host: "192.168.240.1", port: DEFAULT_LISTEN_PORT)
                    count = 0
                }
                count += 1

            })

        UDP.addObserver(observ)

        let sendOb = UDPSendObserver(didSend: { (socket, tag) -> Void in
            NSLog("SEND: \(socket) TAG: \(tag)")

            }, didNotSend: { (socket, tag, error) -> Void in

                NSLog("didNotSend: \(socket) TAG: \(tag) Error: \(error)")

        })
        
        UDP.addObserver(sendOb)

        do {
//            try bob.bindTo(51113)
            try UDP.bindTo(51113, interface: "0.0.0.0")
        } catch {
            print("Errorrrror: \(error)")
        }

        do {
//            try bob.joinMulticast("2001:0db8:85a3:0000:0000:8a2e:0370:7334")
            try UDP.joinMulticast("239.78.80.1")
        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            try UDP.beginReceiving()
        } catch {
            print("Errorrrror: \(error)")
        }


        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
        dispatch_after(when, dispatch_get_main_queue()) {
//            bob.pauseReceiving()
//            bob.send(waspMsg, host: "192.168.240.1", port: DEFAULT_LISTEN_PORT)
        }


        if false {
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(3234234236) { (error) -> Void in

            if (error != nil) {
                XCTFail("Expectation Failed with error: \(error)");
            }

        }

    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
