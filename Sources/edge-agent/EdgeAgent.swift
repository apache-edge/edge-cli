import ArgumentParser
import Foundation

@main
struct EdgeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edge-agent",
        abstract: "Edge Agent",
        subcommands: []
    )
}
