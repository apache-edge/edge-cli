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

    @Flag(name: .shortAndLong, help: "Attach a debugger to the container")
    var debug: Bool = false

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
            .product(executableTarget.name),
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

        var imageSpec = ContainerImageSpec.withExecutable(executable: executable)

        if debug {
            // Include the ds2 executable in the container image.
            guard
                let ds2URL = Bundle.module.url(
                    forResource: "ds2-124963fd-static-linux-arm64",
                    withExtension: nil
                )
            else {
                fatalError("Could not find ds2 executable in bundle resources")
            }

            let ds2Files = [
                ContainerImageSpec.Layer.File(
                    source: ds2URL,
                    destination: "/bin/ds2",
                    permissions: 0o755
                )
            ]
            let ds2Layer = ContainerImageSpec.Layer(files: ds2Files)
            imageSpec.layers.insert(ds2Layer, at: 0)
        }

        let outputPath = "\(executableTarget.name)-container.tar"
        try await buildDockerContainerImage(
            image: imageSpec,
            imageName: imageName,
            outputPath: outputPath
        )

        logger.info(
            "Loading into Docker",
            metadata: [
                "imageName": .string(imageName),
                "path": .string(outputPath),
            ]
        )
        try await Shell.run(["docker", "load", "-i", outputPath])

        if debug {
            logger.info(
                "Running container with debugger",
                metadata: ["imageName": .string(imageName)]
            )
            try await Shell.run([
                "docker", "run", "--rm", "-it", "-p", "4242:4242",
                "--cap-add=SYS_PTRACE", "--security-opt", "seccomp=unconfined", imageName,
                "ds2", "gdbserver", "0.0.0.0:4242", "/bin/\(executableTarget.name)",
            ])
            return
        }

        logger.info("Running container", metadata: ["imageName": .string(imageName)])
        try await Shell.run(["docker", "run", "--rm", imageName])

    }
}
