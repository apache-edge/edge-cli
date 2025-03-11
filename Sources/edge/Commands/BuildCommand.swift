import ArgumentParser
import Foundation
import EdgeCLI

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build EdgeOS projects."
    )
    
    func run() async throws {
        let swiftPM = SwiftPM()
        try await swiftPM.build()
    }
}