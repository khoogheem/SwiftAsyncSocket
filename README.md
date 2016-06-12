# SwiftAsyncSocket
Asynchronous Socket in Swift.  Modeled after CocoaAsyncSocket

Currently support for UDP

###Linux
Current support for Linux is in progress.  This requires the use of libDispatch which is currently being worked on.

###Example Usage

```
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
                try UDP.bindTo(port: 54022)
            #else
                try UDP.bindTo(54022)
            #endif

        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            #if swift(>=3.0)
                try UDP.joinMulticast(group: "239.78.80.110")
            #else
                try UDP.joinMulticast("239.78.80.101")
            #endif

        } catch {
            print("Errorrrror: \(error)")
        }

        do {
            try UDP.beginReceiving()
        } catch {
            print("Errorrrror: \(error)")
        }
```
