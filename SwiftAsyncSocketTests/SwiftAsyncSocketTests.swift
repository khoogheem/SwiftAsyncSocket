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


class SwiftAsyncSocketTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testBind() {
        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        do {
            try UDP.bindTo(54022, interface: "0.0.0.0")
        } catch {
            print("Errorrrror: \(error)")
            XCTFail()

        }

    }

    func testJoinMulticastIPV4() {
        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        do {
            try UDP.bindTo(54022, interface: "0.0.0.0")
        } catch {
            print("Errorrrror: \(error)")
            XCTFail()

        }

        do {
            try UDP.joinMulticast("239.78.80.110")
        } catch {
            print("Errorrrror: \(error)")
            XCTFail()
        }

    }

    func testJoinMulticastIPV6() {
        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        do {
            try UDP.bindTo(54022, interface: "2002:3289:d71c::1610:9fff:fed6:475d")
        } catch {
            print("Errorrrror: \(error)")
            XCTFail()

        }

        do {
            try UDP.joinMulticast("FF01:0:0:0:0:0:0:201")
        } catch {
            print("Errorrrror: \(error)")
            XCTFail()
        }
        
    }

    
    func testExample() {

        let expectation: XCTestExpectation = expectationWithDescription("test")

        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        let observ = UDPReceiveObserver(closeHandler: { thesock, error -> Void in

            NSLog("Socket did Close: \(error)")

            }, receiveHandler: { (theSocket, data, host, port) -> Void in

                print("\n Data: \(data) from: \(host) onPort:\(port)")

            })

        UDP.addObserver(observ)

        let sendOb = UDPSendObserver(didSend: { (socket, tag) -> Void in
            NSLog("SEND: \(socket) TAG: \(tag)")

            }, didNotSend: { (socket, tag, error) -> Void in

                NSLog("didNotSend: \(socket) TAG: \(tag) Error: \(error)")

        })
        
        UDP.addObserver(sendOb)

        do {
            try UDP.bindTo(54022, interface: "0.0.0.0")
        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            try UDP.joinMulticast("239.78.80.110")
        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            try UDP.beginReceiving()
        } catch {
            print("Errorrrror: \(error)")
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
