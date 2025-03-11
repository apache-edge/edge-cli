import Foundation

/// Represents the Swift Package Manager interface for building and managing Swift packages.
public struct SwiftPM {
    public let path: String

    public init(path: String = "/usr/bin/swift") {
        self.path = path
    }

    public enum BuildOption {
        /// Filter for selecting a specific Swift SDK to build with.
        case swiftSDK(String)

        /// Print the binary output path
        case showBinPath

        /// Built the specified target.
        case target(String)

        case quiet

        /// The arguments to pass to the Swift build command.
        var arguments: [String] {
            switch self {
            case .swiftSDK(let sdk):
                return ["--swift-sdk", sdk]
            case .showBinPath:
                return ["--show-bin-path"]
            case .target(let target):
                return ["--target", target]
            case .quiet:
                return ["--quiet"]
            }
        }
    }

    /// Build the Swift package.
    @discardableResult public func build(_ options: BuildOption...) async throws -> String {
        let arguments = [path, "build"] + options.flatMap(\.arguments)
        return try await Shell.run(arguments)
    }

    public func dumpPackage() async throws -> Package {
        let arguments = [path, "package", "dump-package"]
        let output = try await Shell.run(arguments)
        return try JSONDecoder().decode(Package.self, from: Data(output.utf8))
    }

    /// The return type of the `dumpPackage` method.
    /// Currently incomplete.
    public struct Package: Decodable {
        public var targets: [Target]

        public struct Target: Decodable {
            public var name: String
            public var type: String
        }
    }
}