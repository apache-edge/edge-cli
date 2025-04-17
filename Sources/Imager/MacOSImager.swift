#if os(macOS)
import Foundation
import DiskArbitration

/// A macOS implementation of the `Imager` protocol.
///
/// This class provides functionality for writing image files to drives on macOS systems
/// using native APIs.
@available(macOS 10.15, *)
public class MacOSImager: Imager, @unchecked Sendable {
    /// Path to the image file to be imaged.
    public let imageFilePath: String
    
    /// Path to the drive to be imaged.
    public let drivePath: String
    
    /// The current state of the imaging process.
    public private(set) var state: ImagerState = .idle
    
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
    /// - Parameter onlyExternalDrives: If `true`, only external drives are returned.
    /// - Returns: An array of `Drive` objects representing the available drives.
    /// - Throws: An `ImagerError` if there is an error getting or parsing drive information.
    public func availableDrivesToImage(onlyExternalDrives: Bool) throws -> [Drive] {
        // Step 1: Get the list of whole disk identifiers and map whole disks to their mountable partitions
        let listTask = Process()
        listTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        listTask.arguments = ["list", "-plist"]
        let listPipe = Pipe()
        listTask.standardOutput = listPipe

        var wholeDiskIdentifiers: [String] = []
        do {
            try listTask.run()
            let listData = listPipe.fileHandleForReading.readDataToEndOfFile()
            listTask.waitUntilExit()
            guard listTask.terminationStatus == 0 else {
                throw ImagerError.driveDetectionError(reason: "diskutil list failed with status \(listTask.terminationStatus)")
            }
            guard let listPlist = try? PropertyListSerialization.propertyList(from: listData, options: [], format: nil) as? [String: Any],
                  let wholeDisksIdentifiers = listPlist["WholeDisks"] as? [String],
                  let allDisksAndPartitions = listPlist["AllDisksAndPartitions"] as? [[String: Any]] else {
                throw ImagerError.driveDetectionError(reason: "Error running or parsing diskutil list: Invalid output format or missing keys")
            }
            wholeDiskIdentifiers = wholeDisksIdentifiers

            // Create a map from whole disk identifier (e.g., "disk28") to its first mountable partition identifier (e.g., "disk28s1")
            var wholeDiskToPartitionMap: [String: String] = [:]
            for diskEntry in allDisksAndPartitions {
                if let wholeDiskId = diskEntry["DeviceIdentifier"] as? String,
                   let partitions = diskEntry["Partitions"] as? [[String: Any]] {
                    for partition in partitions {
                        if let partitionId = partition["DeviceIdentifier"] as? String,
                           let mountPoint = partition["MountPoint"] as? String,
                           !mountPoint.isEmpty {
                            wholeDiskToPartitionMap[wholeDiskId] = partitionId
                            break // Found the first mountable partition for this disk
                        }
                    }
                }
            }

            // Step 2: Get detailed info, filter, and find available space
            var availableDrives: [Drive] = []
            guard let session = DASessionCreate(kCFAllocatorDefault) else {
                throw ImagerError.driveDetectionError(reason: "Failed to create DiskArbitration session")
            }

            for diskIdentifier in wholeDiskIdentifiers {
                let path = "/dev/\(diskIdentifier)"
                let infoTask = Process()
                infoTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                infoTask.arguments = ["info", "-plist", path]
                let infoPipe = Pipe()
                infoTask.standardOutput = infoPipe

                do {
                    try infoTask.run()
                    let infoData = infoPipe.fileHandleForReading.readDataToEndOfFile()
                    infoTask.waitUntilExit()

                    guard infoTask.terminationStatus == 0,
                          let infoPlist = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any] else {
                        continue
                    }

                    // --- Get Base Info & Filter using diskutil info on Whole Disk (diskX) ---
                    let isInternal = infoPlist["Internal"] as? Bool ?? false
                    let isSystemImage = infoPlist["SystemImage"] as? Bool ?? false
                    let virtualOrPhysical = infoPlist["VirtualOrPhysical"] as? String ?? "Physical"
                    let isVirtualDevice = (virtualOrPhysical == "Virtual")

                    // Apply filtering first
                    let isSuitableExternal = !isInternal && !isSystemImage && !isVirtualDevice
                    if onlyExternalDrives && !isSuitableExternal {
                        continue // Skip this whole disk if filtering for external and it doesn't match
                    }

                    // --- Get Mount Point, Available Space, and Name (via Partition diskXsY) ---
                    var available: Int64? = nil
                    var volumeNameFromPartition: String? = nil // Store name found from partition
                    let capacity = infoPlist["TotalSize"] as? Int64 ?? 0 // Capacity comes from whole disk

                    // Find the partition identifier associated with this whole disk
                    if let partitionIdentifier = wholeDiskToPartitionMap[diskIdentifier] {
                        let partitionPath = "/dev/\(partitionIdentifier)"

                        if let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, partitionPath) {
                            if let diskInfoDA = DADiskCopyDescription(disk) as? [String: Any] {
                                // Attempt to get name from partition's DA description
                                volumeNameFromPartition = diskInfoDA[kDADiskDescriptionVolumeNameKey as String] as? String

                                if let mountURL = diskInfoDA[kDADiskDescriptionVolumePathKey as String] as? URL {
                                    let mountPoint = mountURL.path
                                    if !mountPoint.isEmpty {
                                        // Extra check: Don't include root if filtering external
                                        if !(onlyExternalDrives && mountPoint == "/") {
                                            do {
                                                let attributes = try FileManager.default.attributesOfFileSystem(forPath: mountPoint)
                                                available = attributes[.systemFreeSize] as? Int64
                                            } catch {
                                                available = nil // Failed FileManager
                                            }
                                        } // else: Skip root disk if filtering
                                    } // else: DA gave empty mount point for partition
                                } // else: DA description for partition missing mount point
                            } // else: Failed DA CopyDescription for partition
                        } // else: Failed DA Create Disk for partition
                    } // else: No mountable partition found for this whole disk in the map

                    // Only add the drive if it passed the initial filter (or we aren't filtering)
                    // Use the name found from the partition if available
                    let drive = Drive(path: path, capacity: capacity, available: available, name: volumeNameFromPartition)
                    availableDrives.append(drive)

                } catch {
                    // Error running diskutil info process for this disk
                    continue
                }
            }

            // Sort drives by path for consistent ordering
            return availableDrives.sorted { $0.path < $1.path }
        } catch let error as ImagerError {
            throw error
        } catch {
            throw ImagerError.driveDetectionError(reason: "Error running or parsing diskutil list: \(error.localizedDescription)")
        }
    }

    /// Initialize a new imager with the specified image file and drive paths.
    ///
    /// - Parameters:
    ///   - imageFilePath: The path to the image file to be written.
    ///   - drivePath: The path to the drive where the image will be written.
    public required init(imageFilePath: String, drivePath: String) {
        self.imageFilePath = imageFilePath
        self.drivePath = drivePath
    }

    /// Begin imaging the drive.
    ///
    /// This method starts the process of writing the image file to the drive.
    /// It may throw an `ImagerError` if the operation cannot be completed.
    public func startImaging() throws {
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
            // Get list of all physical drives from the system
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            task.arguments = ["list", "-plist", "physical"]

            let pipe = Pipe()
            task.standardOutput = pipe

            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            if task.terminationStatus == 0, let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allDisks = plist["WholeDisks"] as? [String] {

                if allDisks.contains(drivePath) {
                    // It's a physical drive
                } else {
                    let reason = "Selected drive is not a physical drive. For safety, only physical drives can be imaged."
                    state = .failed(.invalidDrive(reason: reason))
                    throw ImagerError.invalidDrive(reason: reason)
                }
            } else {
                throw ImagerError.driveDetectionError(reason: "Failed to parse disk information")
            }
        } catch let error as ImagerError {
            throw error
        } catch {
            throw ImagerError.driveDetectionError(reason: "Failed to verify if drive is physical: \(error.localizedDescription)")
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
    public func stopImaging() throws {
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
    public func progress(_ handler: @escaping (Progress, ImagerError?) -> Void) {
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

            if task.terminationStatus == 0, let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
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