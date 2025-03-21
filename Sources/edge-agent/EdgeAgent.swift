import ArgumentParser
import EdgeAgentGRPC
import Foundation
import GRPCHealthService
import GRPCNIOTransportHTTP2
import GRPCServiceLifecycle
import Logging
import ServiceLifecycle

@main
struct EdgeAgent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edge-agent",
        abstract: "Edge Agent"
    )

    @Option(name: .shortAndLong, help: "The port to listen on for incoming connections.")
    var port: Int = 50051

    func run() async throws {
        let logger = Logger(label: "apache-edge.agent")

        logger.info("Starting Edge Agent on port \(port)")

        let transport = HTTP2ServerTransport.Posix(
            address: .ipv4(host: "0.0.0.0", port: port),
            transportSecurity: .plaintext
        )

        let healthService = HealthService()

        let grpcServer = GRPCServer(
            transport: transport,
            services: [
                healthService
            ]
        )

        let group = ServiceGroup(
            services: [
                grpcServer
            ],
            logger: logger
        )

        try await group.run()
    }
}
