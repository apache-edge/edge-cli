// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "edge-cli",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        /// The main executable provided by edge-cli.
        .executableTarget(
            name: "edge",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "EdgeCLI")
            ]
        ),

        /// The EdgeAgent executable. It's currently here for development purposes, and will be
        /// moved to a separate package in the future.
        .executableTarget(
            name: "EdgeAgent",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        /// Contains everything EdgeCLI, except for the command line interface.
        .target(
            name: "EdgeCLI",
            dependencies: [
                .target(name: "ContainerBuilder"),
                .target(name: "Shell"),
            ]
        ),

        /// Tools to build OCI-compliant container images.
        .target(
            name: "ContainerBuilder",
            dependencies: [
                .target(name: "Shell"),
            ]
        ),
        
        /// Utility for executing shell commands.
        .target(name: "Shell"),
    ]
)
