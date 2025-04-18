#if os(macOS)

    import Foundation
    import DiskArbitration
    import Darwin

    public struct MacOSImager: Imager, @unchecked Sendable {
        public var imageFilePath: String
        public var drivePath: String
        private var fullDrivePath: String {
            return "/dev/\(drivePath)"
        }

        public init(imageFilePath: String, drivePath: String) {
            self.imageFilePath = imageFilePath
            self.drivePath = drivePath
        }

        public func startImaging(
            handler: @Sendable @escaping (_ progress: Foundation.Progress, _ error: ImagerError?) ->
                Void
        ) {

            // 1. check that the image file exists
            guard FileManager.default.fileExists(atPath: imageFilePath) else {
                handler(.init(), ImagerError.invalidImageFile(reason: "Image file does not exist"))
                return
            }

            // 2. check that the drive exists
            guard FileManager.default.fileExists(atPath: fullDrivePath) else {
                handler(.init(), ImagerError.invalidDrive(reason: "Drive does not exist or is not accessible"))
                return
            }

            let isMounted = self.isMounted(drivePath: drivePath)
            // 3. If the drive is mounted, try to unmount it
            if isMounted {
                print("Drive is mounted, unmounting...")
                // Try to unmount the drive
                let unmountProcess = Process()
                unmountProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                unmountProcess.arguments = ["unmountDisk", drivePath]

                do {
                    try unmountProcess.run()
                    unmountProcess.waitUntilExit()

                    // Check if unmount was successful
                    if unmountProcess.terminationStatus != 0 {
                        handler(
                            .init(),
                            ImagerError.permissionDenied(reason: "Failed to unmount drive")
                        )
                        return
                    }
                    
                    // Double-check that the drive is actually unmounted now
                    if self.isMounted(drivePath: drivePath) {
                        handler(
                            .init(),
                            ImagerError.permissionDenied(reason: "Drive is still mounted after unmount attempt")
                        )
                        return
                    }
                    
                    print("Drive successfully unmounted.")
                } catch {
                    handler(
                        .init(),
                        ImagerError.permissionDenied(
                            reason: "Failed to unmount drive: \(error.localizedDescription)"
                        )
                    )
                    return
                }
            }

            // 4. Check permissions on the drive
            do {
                // We don't need to store the attributes, just check if we can access them
                _ = try FileManager.default.attributesOfItem(atPath: fullDrivePath)
            } catch {
                handler(
                    .init(),
                    ImagerError.permissionDenied(
                        reason: "Cannot get attributes of drive: \(error.localizedDescription)"
                    )
                )
                return
            }
            
            // 5. Check if we're running with sufficient privileges
            if geteuid() != 0 {
                handler(
                    .init(),
                    ImagerError.permissionDenied(
                        reason: "This operation requires administrative privileges. Please run with sudo."
                    )
                )
                return
            }
            
            // 6. Get the image file size for progress tracking
            let imageFileAttributes: [FileAttributeKey: Any]
            do {
                imageFileAttributes = try FileManager.default.attributesOfItem(atPath: imageFilePath)
            } catch {
                handler(
                    .init(),
                    ImagerError.invalidImageFile(
                        reason: "Cannot get attributes of image file: \(error.localizedDescription)"
                    )
                )
                return
            }
            
            guard let imageFileSize = imageFileAttributes[.size] as? Int64, imageFileSize > 0 else {
                handler(
                    .init(),
                    ImagerError.invalidImageFile(reason: "Cannot determine image file size")
                )
                return
            }

            // 7. start imaging
            // Create a progress object to track and report imaging progress
            let progress = Progress(totalUnitCount: imageFileSize)
            progress.kind = .file
            progress.fileOperationKind = .copying

            // Setup the dd command to perform the imaging
            let ddProcess = Process()
            ddProcess.executableURL = URL(fileURLWithPath: "/bin/dd")
            ddProcess.arguments = [
                "if=\(imageFilePath)",
                "of=\(fullDrivePath)",
                "bs=1m",
                "status=progress",
            ]

            // Set up pipes for stdout and stderr
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            ddProcess.standardOutput = outputPipe
            ddProcess.standardError = errorPipe

            // Monitor output to track progress
            outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    // Parse dd output for progress information
                    if let bytesTransferred = self.parseProgress(from: output) {
                        DispatchQueue.main.async {
                            // Update progress with the bytes transferred
                            progress.completedUnitCount = bytesTransferred
                            handler(progress, nil)
                        }
                    }
                    
                    // Print raw output for debugging (to standard error)
                    fputs("DD Output: \(output)\n", stderr)
                }
            }

            // Monitor for errors
            errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if !data.isEmpty, let errorOutput = String(data: data, encoding: .utf8) {
                    if !errorOutput.isEmpty {
                        print("Error output: \(errorOutput)")
                    }
                }
            }

            // Handle process termination
            ddProcess.terminationHandler = { process in
                // Clean up file handles
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    progress.completedUnitCount = progress.totalUnitCount
                    handler(progress, nil)
                } else {
                    handler(
                        progress,
                        ImagerError.processingInterrupted(
                            reason: "dd process exited with status \(process.terminationStatus)"
                        )
                    )
                }
            }

            do {
                try ddProcess.run()
                // Initial progress update
                handler(progress, nil)
            } catch {
                handler(
                    progress,
                    ImagerError.processingInterrupted(
                        reason: "Failed to start dd process: \(error.localizedDescription)"
                    )
                )
            }

        }

        private func parseProgress(from output: String) -> Int64? {
            // dd on macOS typically outputs progress in formats like:
            // "123456789 bytes transferred in 0.012345 secs (123456789 bytes/sec)"
            // or "1.2 GB copied, 30.1 s, 40.2 MB/s"
            
            // Look for patterns in dd output
            let bytesPattern = "(\\d+)\\s+bytes\\s+(transferred|copied)"
            let mbPattern = "(\\d+(\\.\\d+)?)\\s+[MG]B\\s+(transferred|copied)"
            let gbPattern = "(\\d+(\\.\\d+)?)\\s+GB\\s+(transferred|copied)"
            
            // Try to match bytes first (most precise)
            if let bytesMatch = output.range(of: bytesPattern, options: .regularExpression),
               let bytesStr = output[bytesMatch].firstMatch(of: /(\d+)/),
               let bytes = Int64(bytesStr.1)
            {
                return bytes
            } 
            // Try to match MB
            else if let mbMatch = output.range(of: mbPattern, options: .regularExpression),
                    let mbStr = output[mbMatch].firstMatch(of: /(\d+(\.\d+)?)/),
                    let mb = Double(mbStr.1)
            {
                // Convert MB to bytes (1 MB = 1,048,576 bytes)
                return Int64(mb * 1_048_576)
            }
            // Try to match GB
            else if let gbMatch = output.range(of: gbPattern, options: .regularExpression),
                    let gbStr = output[gbMatch].firstMatch(of: /(\d+(\.\d+)?)/),
                    let gb = Double(gbStr.1)
            {
                // Convert GB to bytes (1 GB = 1,073,741,824 bytes)
                return Int64(gb * 1_073_741_824)
            }
            
            // Alternative pattern for macOS dd status=progress output
            // Example: "1234+0 records in\n1234+0 records out\n1234567890 bytes transferred in 123.456789 secs (123456789 bytes/sec)"
            if let recordsOutMatch = output.range(of: "(\\d+)\\+\\d+\\s+records\\s+out", options: .regularExpression),
               let recordsOutStr = output[recordsOutMatch].firstMatch(of: /(\d+)/),
               let recordsOut = Int64(recordsOutStr.1)
            {
                // Each record is typically 512 bytes or the specified block size (bs)
                // We're using bs=1m (1 MiB) in our dd command
                return recordsOut * 1_048_576
            }

            return nil
        }

        // MARK: - Helper Functions

        private func isMounted(drivePath: String) -> Bool {
            guard let session = DASessionCreate(kCFAllocatorDefault) else {
                fputs("Failed to create Disk Arbitration session.\n", stderr)
                return false
            }

            // We expect drivePath to be just the disk identifier (e.g., "disk28")
            // No need to extract from URL, just use it directly
            let bsdName = drivePath

            guard !bsdName.isEmpty,
                let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName)
            else {
                // Disk might not exist or path is invalid
                print("Debug: Could not create disk reference for \(bsdName)")
                return false
            }

            // DADiskCopyDescription returns a CFDictionary?. Cast to Swift dictionary.
            guard let description = DADiskCopyDescription(disk) as? [String: AnyObject] else {
                // Failed to get description
                print("Debug: Could not get disk description for \(bsdName)")
                return false
            }

            // Check if the volume path key exists. If it does, the volume is mounted.
            // The value associated with kDADiskDescriptionVolumePathKey is a CFURLRef.
            return description[kDADiskDescriptionVolumePathKey as String] != nil
        }
    }

#endif  // os(macOS)
