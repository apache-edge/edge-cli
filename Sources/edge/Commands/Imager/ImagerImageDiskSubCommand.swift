import Imager
import ArgumentParser
import Foundation

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

        let imager = MacOSImager(imageFilePath: source, drivePath: drivePath)

        do {
            // startImaging is synchronous, but handles launching the process
            try imager.startImaging()
            // If startImaging returns without throwing, the process was initiated.
            // Actual success/failure/progress is handled internally by MacOSImager (potentially).
            // A more robust solution would involve async streams for progress.
            print("\nImaging process initiated successfully.")
            print("Monitor system activity or logs for completion.")
        } catch let error as ImagerError {
            print("\nError during imaging: \(error.description)")
            throw ExitCode.failure
        } catch {
            print("\nAn unexpected error occurred: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}