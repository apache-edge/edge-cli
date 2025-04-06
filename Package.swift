// swift-tools-version: 6.0.3
import PackageDescription

let package = Package(
    name: "edge-cli",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "edge", targets: ["edge"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.2"),
        .package(
            url: "https://github.com/apache-edge/edge-agent-common.git",
            revision: "296c7a7781621d2cc8c81f6bbb5a4b48bc030e52"
        ),
    ],
    targets: [
        /// The main executable provided by edge-cli.
        .executableTarget(
            name: "edge",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "EdgeAgentGRPC", package: "edge-agent-common"),
                .target(name: "EdgeCLI"),
            ],
            resources: [
                .copy("Resources")
            ]
        ),

        /// Contains everything EdgeCLI, except for the command line interface.
        .target(
            name: "EdgeCLI",
            dependencies: [
                .target(name: "ContainerBuilder"),
                .product(name: "Shell", package: "edge-agent-common"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        /// Tools to build OCI-compliant container images.
        .target(
            name: "ContainerBuilder",
            dependencies: [
                .product(name: "Shell", package: "edge-agent-common"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
    ]
)
