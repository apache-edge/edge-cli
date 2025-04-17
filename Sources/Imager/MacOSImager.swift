#if os(macOS)
import Foundation
import DiskArbitration

/// A macOS implementation of the `Imager` protocol.
///
/// This class provides functionality for writing image files to drives on macOS systems
/// using native APIs.
@available(macOS 10.15, *)
class MacOSImager: Imager, @unchecked Sendable {
    /// Path to the image file to be imaged.
    let imageFilePath: String
    
    /// Path to the drive to be imaged.
    let drivePath: String
    
    /// The current state of the imaging process.
    private(set) var state: ImagerState = .idle
    
    /// Progress handler closure.
    private var progressHandler: ((Progress, ImagerError?) -> Void)?
    
    /// File handle for the image file.
    private var imageFileHandle: FileHandle?
    
    /// File handle for the drive.
    private var driveFileHandle: FileHandle?
    
    /// Buffer size for reading/writing operations.
    private let bufferSize = 1024 * 1024 // 1MB buffer
    
    /// Get a list of available drives that can be imaged in alphabetical order.
    ///
    /// - Parameter onlyExternalDrives: If true, only external drives will be returned.
    /// - Returns: An array of drive identifiers that can be used for imaging.
    /// - Throws: An `ImagerError` if the drives cannot be enumerated.
    func availableDrivesToImage(onlyExternalDrives: Bool) throws -> [String] {
        // Get list of all physical drives from the system
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["list", "-plist", "physical"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0, let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allDisks = plist["WholeDisks"] as? [String] {
                
                if onlyExternalDrives {
                    // Filter to only include external drives
                    var externalDisks: [String] = []
                    var errors: [String] = []
                    
                    for disk in allDisks {
                        do {
                            if try isExternalDrive(disk) {
                                externalDisks.append(disk)
                            }
                        } catch let error as ImagerError {
                            // Collect errors but continue processing other disks
                            errors.append("\(disk): \(error.description)")
                        } catch {
                            errors.append("\(disk): \(error.localizedDescription)")
                        }
                    }
                    
                    // If we couldn't process any disks due to errors, throw an error
                    if externalDisks.isEmpty && !errors.isEmpty {
                        throw ImagerError.driveDetectionError(reason: "Failed to detect external drives: \(errors.joined(separator: "; "))")
                    }
                    
                    return externalDisks.sorted()
                } else {
                    // Return all drives
                    return allDisks.sorted()
                }
            } else {
                throw ImagerError.driveDetectionError(reason: "Failed to parse disk information")
            }
        } catch let error as ImagerError {
            throw error
        } catch {
            throw ImagerError.driveDetectionError(reason: "Error getting available drives: \(error.localizedDescription)")
        }
    }
    
    /// Determines if a disk is an external drive.
    ///
    /// - Parameter diskName: The name of the disk to check.
    /// - Returns: `true` if the disk is an external drive, `false` otherwise.
    /// - Throws: An `ImagerError` if there is an error checking the drive.
    private func isExternalDrive(_ diskName: String) throws -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["info", "-plist", diskName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0, let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                // Check if it's external
                if let isExternal = plist["External"] as? Bool, isExternal {
                    // Check if it's ejectable (typically means removable)
                    if let isEjectable = plist["Ejectable"] as? Bool, isEjectable {
                        // Check if it's not the system disk
                        if let isSystemDisk = plist["SystemImage"] as? Bool, !isSystemDisk {
                            // Additional safety check: make sure it's not the boot drive
                            if let volumeName = plist["VolumeName"] as? String, volumeName != "Macintosh HD" {
                                return true
                            }
                        }
                    }
                }
                
                // Not an external drive based on our criteria
                return false
            } else {
                throw ImagerError.driveDetectionError(reason: "Failed to get disk information for \(diskName)")
            }
        } catch let error as ImagerError {
            throw error
        } catch {
            throw ImagerError.driveDetectionError(reason: "Error checking if \(diskName) is external: \(error.localizedDescription)")
        }
    }
    
    /// Initialize a new imager with the specified image file and drive paths.
    ///
    /// - Parameters:
    ///   - imageFilePath: The path to the image file to be written.
    ///   - drivePath: The path to the drive where the image will be written.
    required init(imageFilePath: String, drivePath: String) {
        self.imageFilePath = imageFilePath
        self.drivePath = drivePath
    }
    
    /// Begin imaging the drive.
    ///
    /// This method starts the process of writing the image file to the drive.
    /// It may throw an `ImagerError` if the operation cannot be completed.
    func startImaging() throws {
        // Validate image file
        guard FileManager.default.fileExists(atPath: imageFilePath) else {
            state = .failed(.invalidImageFile(reason: "Image file does not exist"))
            throw ImagerError.invalidImageFile(reason: "Image file does not exist")
        }
        
        // Check file extension
        let fileExtension = URL(fileURLWithPath: imageFilePath).pathExtension.lowercased()
        guard ["zip", "tar", "img"].contains(fileExtension) else {
            let reason = "Unsupported file format: \(fileExtension). Only zip, tar, and img formats are supported."
            state = .failed(.invalidImageFile(reason: reason))
            throw ImagerError.invalidImageFile(reason: reason)
        }
        
        // Validate drive
        let driveURL = URL(fileURLWithPath: "/dev/\(drivePath)")
        let drivePath = driveURL.path
        
        guard FileManager.default.fileExists(atPath: drivePath) else {
            let reason = "Drive does not exist at path: \(drivePath)"
            state = .failed(.invalidDrive(reason: reason))
            throw ImagerError.invalidDrive(reason: reason)
        }
        
        // Verify it's an external drive for safety
        do {
            guard try isExternalDrive(self.drivePath) else {
                let reason = "Selected drive is not an external drive. For safety, only external drives can be imaged."
                state = .failed(.invalidDrive(reason: reason))
                throw ImagerError.invalidDrive(reason: reason)
            }
        } catch {
            if let imagerError = error as? ImagerError {
                state = .failed(imagerError)
                throw imagerError
            } else {
                let imagerError = ImagerError.driveDetectionError(reason: "Failed to verify if drive is external: \(error.localizedDescription)")
                state = .failed(imagerError)
                throw imagerError
            }
        }
        
        // Get image file size
        let imageAttributes = try FileManager.default.attributesOfItem(atPath: imageFilePath)
        guard let imageSize = imageAttributes[.size] as? Int64 else {
            let reason = "Could not determine image file size"
            state = .failed(.invalidImageFile(reason: reason))
            throw ImagerError.invalidImageFile(reason: reason)
        }
        
        // Get drive size
        let driveSize = try getDriveSize(drive: drivePath)
        
        // Check if image fits on drive
        if imageSize > driveSize {
            state = .failed(.imageTooLargeForDrive(imageSize: UInt64(imageSize), driveSize: UInt64(driveSize)))
            throw ImagerError.imageTooLargeForDrive(imageSize: UInt64(imageSize), driveSize: UInt64(driveSize))
        }
        
        // Open file handles
        do {
            imageFileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: imageFilePath))
            driveFileHandle = try FileHandle(forWritingTo: driveURL)
        } catch {
            let reason = "Failed to open file handles: \(error.localizedDescription)"
            state = .failed(.permissionDenied(reason: reason))
            throw ImagerError.permissionDenied(reason: reason)
        }
        
        // Start imaging process
        state = .imaging
        
        // Create a background task for imaging
        Task {
            await performImaging(imageSize: imageSize)
        }
    }
    
    /// Stop the imaging process.
    ///
    /// This method stops the imaging process if it is currently running.
    /// It may throw an `ImagerError` if the operation cannot be stopped.
    func stopImaging() throws {
        if case .imaging = state {
            state = .failed(.processingInterrupted(reason: "Imaging process was stopped by user"))
            
            // Close file handles
            if let handle = imageFileHandle {
                try handle.close()
                imageFileHandle = nil
            }
            
            if let handle = driveFileHandle {
                try handle.close()
                driveFileHandle = nil
            }
        } else {
            throw ImagerError.unknown(reason: "Cannot stop imaging: No imaging process is currently running")
        }
    }
    
    /// Register a handler to receive progress updates.
    ///
    /// - Parameter handler: A closure that will be called with progress updates.
    ///   The closure receives the current progress and an optional error if one occurred.
    func progress(_ handler: @escaping (Progress, ImagerError?) -> Void) {
        progressHandler = handler
    }
    
    // MARK: - Private Methods
    
    /// Get the size of a drive in bytes.
    ///
    /// - Parameter drive: The path to the drive.
    /// - Returns: The size of the drive in bytes.
    /// - Throws: An `ImagerError` if the drive size cannot be determined.
    private func getDriveSize(drive: String) throws -> Int64 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["info", "-plist", drive]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if task.terminationStatus == 0, let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let size = plist["TotalSize"] as? Int64 {
                return size
            } else {
                throw ImagerError.invalidDrive(reason: "Could not determine drive size")
            }
        } catch let error as ImagerError {
            throw error
        } catch {
            throw ImagerError.invalidDrive(reason: "Error getting drive size: \(error.localizedDescription)")
        }
    }
    
    /// Perform the actual imaging process.
    ///
    /// - Parameter imageSize: The size of the image file in bytes.
    private func performImaging(imageSize: Int64) async {
        guard let imageFileHandle = imageFileHandle, let driveFileHandle = driveFileHandle else {
            let error = ImagerError.unknown(reason: "File handles not initialized")
            state = .failed(error)
            progressHandler?(Progress(totalBytes: imageSize, completedBytes: 0), error)
            return
        }
        
        var bytesWritten: Int64 = 0
        var lastProgress = Progress(totalBytes: imageSize, completedBytes: bytesWritten)
        
        do {
            // Reset file positions
            try imageFileHandle.seek(toOffset: 0)
            try driveFileHandle.seek(toOffset: 0)
            
            // Read and write in chunks
            while bytesWritten < imageSize {
                // Check if we should continue
                if case .imaging = state {
                    // Continue imaging
                } else {
                    break
                }
                
                // Read a chunk from the image file
                let data = imageFileHandle.readData(ofLength: bufferSize)
                if data.isEmpty {
                    break
                }
                
                // Write the chunk to the drive
                try driveFileHandle.write(contentsOf: data)
                
                // Update progress
                bytesWritten += Int64(data.count)
                let currentProgress = Progress(totalBytes: imageSize, completedBytes: bytesWritten)
                
                // Only update if progress has changed significantly (1% or more)
                if currentProgress.percentage - lastProgress.percentage >= 0.01 {
                    lastProgress = currentProgress
                    state = .progress(currentProgress)
                    progressHandler?(currentProgress, nil)
                }
            }
            
            // Ensure all data is written to disk
            try driveFileHandle.synchronize()
            
            // Update final progress
            let finalProgress = Progress(totalBytes: imageSize, completedBytes: bytesWritten)
            state = .progress(finalProgress)
            progressHandler?(finalProgress, nil)
            
            // Set state to completed
            state = .completed
            
        } catch {
            let imagerError = ImagerError.processingInterrupted(reason: error.localizedDescription)
            state = .failed(imagerError)
            progressHandler?(lastProgress, imagerError)
        }
        
        // Close file handles
        try? imageFileHandle.close()
        try? driveFileHandle.close()
        
        // Reset file handles
        self.imageFileHandle = nil
        self.driveFileHandle = nil
    }
    
    /// Cancel the imaging process.
    @available(*, deprecated, message: "Use stopImaging() instead")
    func cancel() {
        try? stopImaging()
    }
    
    deinit {
        // Ensure file handles are closed
        try? imageFileHandle?.close()
        try? driveFileHandle?.close()
    }
}
#endif