// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NumberGame",
    platforms: [
        .iOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0")
    ],
    targets: [
        .target(
            name: "NumberGame",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ]
        )
    ]
)