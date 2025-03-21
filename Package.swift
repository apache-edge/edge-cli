// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "edge-cli",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "edge", targets: ["edge"]),
        .executable(name: "edge-agent", targets: ["edge-agent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.7.0"),
        .package(url: "https://github.com/grpc/grpc-swift-extras.git", from: "1.0.0"),
    ],
    targets: [
        /// The main executable provided by edge-cli.
        .executableTarget(
            name: "edge",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "EdgeCLI"),
                .product(name: "Logging", package: "swift-log"),
            ],
            resources: [
                .copy("Resources")
            ]
        ),

        /// The EdgeAgent executable. It's currently here for development purposes, and will be
        /// moved to a separate package in the future.
        .executableTarget(
            name: "edge-agent",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),
                .product(name: "GRPCHealthService", package: "grpc-swift-extras"),
                .target(name: "EdgeAgentGRPC"),
            ]
        ),

        /// Contains everything EdgeCLI, except for the command line interface.
        .target(
            name: "EdgeCLI",
            dependencies: [
                .target(name: "ContainerBuilder"),
                .target(name: "Shell"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        /// Tools to build OCI-compliant container images.
        .target(
            name: "ContainerBuilder",
            dependencies: [
                .target(name: "Shell")
            ]
        ),

        /// Utility for executing shell commands.
        .target(
            name: "Shell",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),

        /// Protobuf definitions for the EdgeAgent service.
        .target(
            name: "EdgeAgentGRPC",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            ]
        ),
    ]
)
