import PackageDescription

let package = Package(
    name: "SwiftAsyncSocket",
    dependencies: [
        .Package(url: "./Linux/Dispatch", majorVersion: 1)
        //.Package(url: "https://github.com/sheffler/CDispatch", majorVersion:1)
    ]

)

