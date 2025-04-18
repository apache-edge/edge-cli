import ArgumentParser
import Foundation
import Imager

struct ImagerImageDiskSubCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Write an image file to a specified drive."
    )

    @Option(name: [.long, .customShort("s")], help: "The path to the source image file (.img, .zip, .tar).", completion: .file(extensions: ["img", "zip", "tar"]))
    var source: String

    @Option(name: [.long, .customShort("t")], help: "The target drive path (e.g., disk4). Use 'list-disks' to find available drives.")
    var target: String

    func run() async throws {
        // Basic path validation
        guard !source.isEmpty, !target.isEmpty else {
            print("Error: Both source image path (--source) and target drive path (--target) must be provided.")
            throw ExitCode.failure
        }
        
        // Ensure target doesn't contain /dev/ prefix as MacOSImager expects raw disk name (e.g., disk4)
        let drivePath = target.replacingOccurrences(of: "/dev/", with: "")

        print("Starting imaging process...")
        print("  Source Image: \(source)")
        print("  Target Drive: /dev/\(drivePath)")
        print("  This may take some time...")

        let imager = ImagerFactory.createImager(imageFilePath: source, drivePath: drivePath)
        
        // Setup for progress display
        print("\nProgress: ")
        
        // Create a task to handle the imaging process
        let task = Task {
            // Create an actor to safely handle the lastUpdateTime
            actor ProgressState {
                private var lastUpdateTime = Date()
                
                func shouldUpdate(now: Date, isFinished: Bool) -> Bool {
                    if isFinished || now.timeIntervalSince(lastUpdateTime) >= 0.5 {
                        lastUpdateTime = now
                        return true
                    }
                    return false
                }
            }
            
            let progressState = ProgressState()
            
            // Create a continuation to handle the async callback
            return await withCheckedContinuation { continuation in
                // The startImaging method uses a closure for progress/error handling
                imager.startImaging { [progressState] progress, error in
                    if let error = error {
                        // Clear the current line before showing the error
                        print("\r\u{1B}[2K", terminator: "")
                        print("Error during imaging: \(error.description)")
                        continuation.resume(returning: false)
                    } else {
                        // Handle progress updates
                        Task {
                            let now = Date()
                            // Check if we should update the display
                            let shouldUpdate = await progressState.shouldUpdate(now: now, isFinished: progress.isFinished)
                            
                            if shouldUpdate {
                                // Calculate percentage
                                let percentage = Int(progress.fractionCompleted * 100)
                                
                                // Create progress bar
                                let barWidth = 50
                                let completedWidth = Int(Double(barWidth) * progress.fractionCompleted)
                                let bar = String(repeating: "=", count: completedWidth) + 
                                        String(repeating: " ", count: barWidth - completedWidth)
                                
                                // Display progress
                                print("\r[\(bar)] \(percentage)%", terminator: "")
                                fflush(stdout)
                                
                                // Check for completion
                                if progress.isFinished {
                                    print("\nImaging process completed successfully!")
                                    continuation.resume(returning: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        print("\nImaging process initiated. Press Ctrl+C to cancel.")
        
        // Wait for the imaging process to complete
        let success = await task.value
        
        // Exit with appropriate code
        if !success {
            throw ExitCode.failure
        }
    }
}