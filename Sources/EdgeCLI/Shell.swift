import Foundation

/// Utility for executing shell commands.
enum Shell {
    /// Error thrown when a process execution fails.
    enum Error: Swift.Error, LocalizedError {
        case nonZeroExit(command: [String], exitCode: Int32)
        
        var errorDescription: String? {
            switch self {
            case .nonZeroExit(let command, let exitCode):
                return "Command '\(command.joined(separator: " "))' failed with exit code \(exitCode)"
            }
        }
    }
    
    /// Run a CLI command.
    ///
    /// This method executes a command in a subprocess. If the command is not successful
    /// (indicated by a non-zero exit code), an error is thrown.
    ///
    /// - Parameter arguments: An array of command-line arguments to execute.
    /// - Throws: An error if the command execution fails
    static func run(_ arguments: [String]) async throws {
        let process = Process()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        try process.run()
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Error.nonZeroExit(
                        command: arguments,
                        exitCode: process.terminationStatus
                    ))
                }
            }
        }
    }
} 