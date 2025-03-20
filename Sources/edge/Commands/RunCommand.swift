import ArgumentParser
import Foundation
import EdgeCLI
import ContainerBuilder
import Shell

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run EdgeOS projects."
    )

    enum Error: Swift.Error, CustomStringConvertible {
        case noExecutableTarget

        var description: String {
            switch self {
            case .noExecutableTarget:
                return String(localized: "No executable target found in package")
            }
        }
    }
    
    func run() async throws {
        let swiftPM = SwiftPM()
        let package = try await swiftPM.dumpPackage()

        // For now, just use the first executable target.
        guard let executableTarget = package.targets.first(where: { $0.type == "executable" }) else {
            throw Error.noExecutableTarget
        }

        try await swiftPM.build(.target(executableTarget.name), .swiftSDK("aarch64-swift-linux-musl"))

        let binPath = try await swiftPM.build(.showBinPath, .swiftSDK("aarch64-swift-linux-musl"), .quiet).trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = URL(fileURLWithPath: binPath).appendingPathComponent(executableTarget.name)

        print("Building container")
        try await buildContainer(executable: executable, outputPath: "\(executableTarget.name)-container.tar")

        print("Loading into Docker")
        try await Shell.run(["docker", "load", "-i", "\(executableTarget.name)-container.tar"])

        print("Running container")
        try await Shell.run(["docker", "run", "--rm", "\(executableTarget.name.lowercased())"])
    }
}