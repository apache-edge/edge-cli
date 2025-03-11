/// Represents the Swift Package Manager interface for building and managing Swift packages.
public struct SwiftPM {
    // TODO: Don't hardcode this path, and manage our own toolchains.
    public static let defaultPath = "/Library/Developer/Toolchains/swift-6.0.3-RELEASE.xctoolchain/usr/bin/swift"

    public let path: String

    public init(path: String) {
        self.path = path
    }

    enum BuildOptions {
        /// Filter for selecting a specific Swift SDK to build with.
        case swiftSDK(String)
    }

    /// Build the Swift package.
    public func build() async throws {
        try await Shell.run([path, "build"])
    }
}