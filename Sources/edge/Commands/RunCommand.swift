import ArgumentParser
import ContainerBuilder
import EdgeCLI
import Foundation
import Logging
import Shell

struct RunCommand: AsyncParsableCommand {
    enum Error: Swift.Error, CustomStringConvertible {
        case noExecutableTarget

        var description: String {
            switch self {
            case .noExecutableTarget:
                return String(localized: "No executable target found in package")
            }
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run EdgeOS projects."
    )

    func run() async throws {
        let logger = Logger(label: "apache-edge.cli.run")

        let swiftPM = SwiftPM()
        let package = try await swiftPM.dumpPackage()

        // For now, just use the first executable target.
        guard let executableTarget = package.targets.first(where: { $0.type == "executable" })
        else {
            throw Error.noExecutableTarget
        }

        try await swiftPM.build(
            .target(executableTarget.name),
            .swiftSDK("aarch64-swift-linux-musl")
        )

        let binPath = try await swiftPM.build(
            .showBinPath,
            .swiftSDK("aarch64-swift-linux-musl"),
            .quiet
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = URL(fileURLWithPath: binPath).appendingPathComponent(executableTarget.name)

        logger.info("Building container")
        let imageName = executableTarget.name.lowercased()
        let imageSpec = ContainerImageSpec.withExecutable(executable: executable)
        try await buildDockerContainerImage(
            image: imageSpec,
            imageName: imageName,
            outputPath: "\(executableTarget.name)-container.tar"
        )

        logger.info("Loading into Docker")
        try await Shell.run(["docker", "load", "-i", "\(executableTarget.name)-container.tar"])

        logger.info("Running container")
        try await Shell.run(["docker", "run", "--rm", imageName])
    }
}
