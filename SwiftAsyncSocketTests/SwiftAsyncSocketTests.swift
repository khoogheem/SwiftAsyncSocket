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
            #if swift(>=3.0)
                try UDP.bindTo(port: 54022, interface: "0.0.0.0")
            #else
                try UDP.bindTo(54022, interface: "0.0.0.0")
            #endif

        } catch {
            print("Errorrrror: \(error)")
            XCTFail()

        }

    }

    func testJoinMulticastIPV4() {
        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        do {
            #if swift(>=3.0)
                try UDP.bindTo(port: 54022, interface: "0.0.0.0")
            #else
                try UDP.bindTo(54022, interface: "0.0.0.0")
            #endif

        } catch {
            print("Errorrrror: \(error)")
            XCTFail()

        }

        do {
            #if swift(>=3.0)
                try UDP.joinMulticast(group: "239.78.80.110")
            #else
                try UDP.joinMulticast("239.78.80.110")
            #endif

        } catch {
            print("Errorrrror: \(error)")
            XCTFail()
        }

    }

    func testJoinMulticastIPV6() {
        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        do {
            #if swift(>=3.0)
                try UDP.bindTo(port: 54022, interface: "2002:3289:d71c::1610:9fff:fed6:475d")
            #else
                try UDP.bindTo(54022, interface: "2002:3289:d71c::1610:9fff:fed6:475d")
            #endif

        } catch {
            print("Errorrrror: \(error)")
            XCTFail()

        }

        do {
            #if swift(>=3.0)
                try UDP.joinMulticast(group: "FF01:0:0:0:0:0:0:201")
            #else
                try UDP.joinMulticast("FF01:0:0:0:0:0:0:201")
            #endif

        } catch {
            print("Errorrrror: \(error)")
            XCTFail()
        }
        
    }

    
    func testExample() {
        #if swift(>=3.0)
            let expect: XCTestExpectation = expectation(withDescription: "test")
        #else
            let expect: XCTestExpectation = expectationWithDescription("test")
        #endif



        let UDP: AsyncUDPSocket = AsyncUDPSocket()

        let observ = UDPReceiveObserver(closeHandler: { thesock, error -> Void in

            print("Socket did Close: \(error)")

            }, receiveHandler: { (theSocket, data, host, port) -> Void in

                print("\n Data: \(data) from: \(host) onPort:\(port)")

            })

        #if swift(>=3.0)
            UDP.addObserver(observer: observ)
        #else
            UDP.addObserver(observ)
        #endif


        let sendOb = UDPSendObserver(didSend: { (socket, tag) -> Void in
            print("SEND: \(socket) TAG: \(tag)")

            }, didNotSend: { (socket, tag, error) -> Void in

                print("didNotSend: \(socket) TAG: \(tag) Error: \(error)")

        })

        #if swift(>=3.0)
            UDP.addObserver(observer: sendOb)
        #else
            UDP.addObserver(sendOb)
        #endif


        do {

            #if swift(>=3.0)
                try UDP.bindTo(port: 54022, interface: "0.0.0.0")
            #else
                try UDP.bindTo(54022, interface: "0.0.0.0")
            #endif

        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            #if swift(>=3.0)
                try UDP.joinMulticast(group: "239.78.80.110")
            #else
                try UDP.joinMulticast("239.78.80.110")
            #endif

        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            try UDP.beginReceiving()
        } catch {
            print("Errorrrror: \(error)")
        }

        if false {
            expect.fulfill()
        }

        

        #if swift(>=3.0)
            waitForExpectations(withTimeout: 3234234236) { (error) -> Void in

                if (error != nil) {
                    XCTFail("Expectation Failed with error: \(error)");
                }
                
            }
        #else
            waitForExpectationsWithTimeout(3234234236) { (error) -> Void in

                if (error != nil) {
                XCTFail("Expectation Failed with error: \(error)");
                }
            
            }
        #endif
        


    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.

        #if swift(>=3.0)
            self.measure {
                // Put the code you want to measure the time of here.
            }
        #else
            self.measureBlock {
            // Put the code you want to measure the time of here.
            }
        #endif

    }
    
}
