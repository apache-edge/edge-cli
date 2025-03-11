import Foundation

/// Utility for executing shell commands.
public enum Shell {
    /// Error thrown when a process execution fails.
    public enum Error: Swift.Error, LocalizedError {
        case nonZeroExit(command: [String], exitCode: Int32)
        
        public var errorDescription: String? {
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
    /// - Returns: The output of the command as a string
    /// - Throws: An error if the command execution fails
    @discardableResult public static func run(_ arguments: [String]) async throws -> String {
        // Log the command before execution
        print("Executing: \(arguments.joined(separator: " "))")
        
        let process = Process()
        
        // Create pipes for stdout and stderr to both capture and display output
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutCapture = Pipe()
        let stderrCapture = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = [
            "PATH": "/Library/Developer/Toolchains/swift-6.0.3-RELEASE.xctoolchain/usr/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "TOOLCHAINS": "org.swift.603202412101a"
        ]
        
        stdoutPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if !data.isEmpty {
                FileHandle.standardOutput.write(data)
                stdoutCapture.fileHandleForWriting.write(data)
            }
        }
        
        stderrPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if !data.isEmpty {
                FileHandle.standardError.write(data)
                stderrCapture.fileHandleForWriting.write(data)
            }
        }
        
        try process.run()
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                // Clean up handlers
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                
                // Close write handles to ensure we can read all data
                stdoutCapture.fileHandleForWriting.closeFile()
                stderrCapture.fileHandleForWriting.closeFile()
                
                if process.terminationStatus == 0 {
                    // Read captured output
                    let stdoutData = stdoutCapture.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrCapture.fileHandleForReading.readDataToEndOfFile()
                    
                    // Combine stdout and stderr
                    let combinedData = stdoutData + stderrData
                    let output = String(data: combinedData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
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