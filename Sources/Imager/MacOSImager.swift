#if os(macOS)
import Foundation
import DiskArbitration
import IOKit

/// Concrete implementation of the Imager protocol for macOS.
public class MacOSImager: Imager, @unchecked Sendable { 
    public let imageFilePath: String
    public let drivePath: String
    public var state: ImagerState = .idle
    var progress: Foundation.Progress? 
    var progressObservation: NSKeyValueObservation?
    var progressHandler: ((Foundation.Progress, ImagerError?) -> Void)? 

    private var imageFileHandle: FileHandle?
    private var driveFileHandle: FileHandle?
    private var ddProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private let progressQueue = DispatchQueue(label: "com.apache-edge.imager.progress", qos: .utility)
    private var lastProgressUpdate = Date()

    public required init(imageFilePath: String = "", drivePath: String = "") {
        self.imageFilePath = imageFilePath
        self.drivePath = drivePath
        self.progress = Foundation.Progress(totalUnitCount: 0) 
    }

    // ... availableDrivesToImage (no changes needed here for this fix) ...
    public func availableDrivesToImage(onlyExternalDrives: Bool) throws -> [Drive] {
        // Get whole disk identifiers using diskutil list -plist
        let listTask = Process()
        listTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        listTask.arguments = ["list", "-plist"]
        let listPipe = Pipe()
        listTask.standardOutput = listPipe

        var wholeDiskIdentifiers: [String] = []
        var wholeDiskToPartitionMap: [String: String] = [:] 

        do {
            try listTask.run()
            listTask.waitUntilExit()
            let listData = listPipe.fileHandleForReading.readDataToEndOfFile()

            if listTask.terminationStatus != 0 {
                throw ImagerError.driveDetectionError(reason: "diskutil list failed with status \(listTask.terminationStatus)")
            }
            guard let listPlist = try? PropertyListSerialization.propertyList(from: listData, options: [], format: nil) as? [String: Any],
                  let parsedWholeDisks = listPlist["WholeDisks"] as? [String],
                  let allDisksAndPartitions = listPlist["AllDisksAndPartitions"] as? [[String: Any]] else {
                throw ImagerError.driveDetectionError(reason: "Error running or parsing diskutil list: Invalid output format or missing keys")
            }
            wholeDiskIdentifiers = parsedWholeDisks

            // Create a map from whole disk identifier (e.g., "disk28") to its first mountable partition identifier (e.g., "disk28s1")
            for diskOrPartData in allDisksAndPartitions {
                if let deviceID = diskOrPartData["DeviceIdentifier"] as? String,
                   wholeDiskIdentifiers.contains(deviceID),
                   let partitions = diskOrPartData["Partitions"] as? [[String: Any]],
                   let firstPartition = partitions.first?["DeviceIdentifier"] as? String
                {
                    wholeDiskToPartitionMap[deviceID] = firstPartition
                }
            }

        } catch {
            throw ImagerError.driveDetectionError(reason: "Failed to execute or process diskutil list: \(error.localizedDescription)")
        }

        var drives: [Drive] = []
        let fileManager = FileManager.default
        let currentDASession = DASessionCreate(kCFAllocatorDefault) 
        guard let currentDASession = currentDASession else {
             throw ImagerError.driveDetectionError(reason: "Failed to create temporary DiskArbitration session")
        }

        for wholeDiskIdentifier in wholeDiskIdentifiers {
            let infoTask = Process()
            infoTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            infoTask.arguments = ["info", "-plist", wholeDiskIdentifier]
            let infoPipe = Pipe()
            infoTask.standardOutput = infoPipe

            do {
                try infoTask.run()
                infoTask.waitUntilExit()
                let infoData = infoPipe.fileHandleForReading.readDataToEndOfFile()

                if infoTask.terminationStatus != 0 {
                    continue 
                }

                guard let diskInfoPlist = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any] else {
                    continue
                }

                if onlyExternalDrives, !isSuitableExternal(diskInfo: diskInfoPlist) {
                     continue
                }

                var volumeName: String? = "(No Name)"
                var availableBytes: Int64? = nil
                let bsdName = "/dev/\(wholeDiskIdentifier)"

                guard let partitionIdentifier = wholeDiskToPartitionMap[wholeDiskIdentifier] else {
                     volumeName = diskInfoPlist["VolumeName"] as? String ?? "(No Name)"
                     let capacity = diskInfoPlist["TotalSize"] as? Int64 ?? 0
                      let drive = Drive(
                         path: bsdName,
                         capacity: capacity,
                         available: nil, 
                         name: volumeName
                     )
                     drives.append(drive)
                     continue 
                }

                let partitionBsdName = "/dev/\(partitionIdentifier)"
                if let partitionDisk = DADiskCreateFromBSDName(kCFAllocatorDefault, currentDASession, partitionBsdName) {
                    if let partitionInfo = DADiskCopyDescription(partitionDisk) as? [String: Any] {
                        volumeName = partitionInfo[kDADiskDescriptionVolumeNameKey as String] as? String ?? volumeName
                        
                        if let mountPath = partitionInfo[kDADiskDescriptionVolumePathKey as String] as? URL {
                             do {
                                 let attributes = try fileManager.attributesOfFileSystem(forPath: mountPath.path)
                                 availableBytes = attributes[.systemFreeSize] as? Int64
                             } catch {
                                 
                             }
                         } else {
                            // print("Partition \(partitionIdentifier) is not mounted.")
                         }
                    } else {
                        // print("Failed to get description for partition \(partitionIdentifier).")
                    }
                } else {
                    // print("Failed to create DADiskRef for partition \(partitionIdentifier).")
                }

                let capacity = diskInfoPlist["TotalSize"] as? Int64 ?? 0
                let drive = Drive(
                    path: bsdName, 
                    capacity: capacity,
                    available: availableBytes,
                    name: volumeName
                )
                drives.append(drive)

            } catch {
                continue
            }
        }
        return drives.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    // ... isSuitableExternal (no changes needed) ...
    private func isSuitableExternal(diskInfo: [String: Any]) -> Bool {
        guard let isInternal = diskInfo["Internal"] as? Bool, !isInternal else {
            return false 
        }
        if diskInfo["VirtualOrPhysical"] as? String == "Virtual" {
            return false
        }
         if diskInfo["SystemImage"] as? Bool == true {
             return false
         }
        if (diskInfo["VolumeName"] as? String)?.contains("Recovery") == true {
             // return false // Maybe allow imaging recovery?
        }
        return true
    }


    // ... startImaging, stopImaging ...
    public func startImaging() throws {
        guard imageFilePath != "", drivePath != "" else {
            throw ImagerError.invalidDrive(reason: "Image file path or drive path not set.") 
        }
        guard case .idle = state else { 
            throw ImagerError.processingInterrupted(reason: "Imaging process already running or not idle.") 
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: imageFilePath) else {
            throw ImagerError.invalidImageFile(reason: "Image file not found at \(imageFilePath)") 
        }

        guard fileManager.fileExists(atPath: drivePath) else {
            throw ImagerError.invalidDrive(reason: "Drive path not found at \(drivePath)") 
        }
        let rawDrivePath = drivePath.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
        guard fileManager.fileExists(atPath: rawDrivePath) else {
              throw ImagerError.invalidDrive(reason: "Raw drive device not found at \(rawDrivePath)") 
         }

        print("Unmounting drive \(drivePath)...")
        let unmountTask = Process()
        unmountTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        unmountTask.arguments = ["unmountDisk", "force", drivePath] 
        do {
            try unmountTask.run()
            unmountTask.waitUntilExit()
            if unmountTask.terminationStatus != 0 {
                print("Warning: diskutil unmountDisk failed (status \(unmountTask.terminationStatus)). Proceeding anyway...")
            }
        } catch {
            throw ImagerError.processingInterrupted(reason: "Failed to run diskutil unmountDisk: \(error.localizedDescription)")
        }

        let imageSize: UInt64
        do {
            let imageAttrs = try fileManager.attributesOfItem(atPath: imageFilePath)
            guard let size = imageAttrs[.size] as? UInt64 else {
                throw ImagerError.invalidImageFile(reason: "Could not read image file size attribute.")
            }
            imageSize = size
        } catch {
            throw ImagerError.invalidImageFile(reason: "Could not read image file attributes: \(error.localizedDescription)")
        }
        progress?.totalUnitCount = Int64(imageSize)
        progress?.completedUnitCount = 0

        print("Starting imaging process using dd...")
        print("Source: \(imageFilePath)")
        print("Target: \(rawDrivePath)")

        ddProcess = Process()
        outputPipe = Pipe()
        errorPipe = Pipe()

        guard let ddProcess = ddProcess, let errorPipe = errorPipe else {
            throw ImagerError.processingInterrupted(reason: "Failed to create process or pipes for dd.")
        }

        ddProcess.executableURL = URL(fileURLWithPath: "/bin/dd")
        ddProcess.arguments = ["if=\(imageFilePath)", "of=\(rawDrivePath)", "bs=4m", "status=progress"]

        ddProcess.standardError = errorPipe

        ddProcess.terminationHandler = { [weak self] process in
            self?.progressQueue.async {
                self?.handleImagingCompletion(process: process)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                self?.progressQueue.async {
                     errorPipe.fileHandleForReading.readabilityHandler = nil 
                }
            } else {
                self?.progressQueue.async {
                    if let output = String(data: data, encoding: .utf8) {
                        self?.parseDdProgress(output)
                    }
                }
            }
        }

        do {
            try ddProcess.run()
            state = .imaging
            print("dd process started (PID: \(ddProcess.processIdentifier)).")
        } catch {
            state = .idle
            cleanupResources()
            throw ImagerError.processingInterrupted(reason: "Failed to launch dd process: \(error.localizedDescription)")
        }
    }

    public func stopImaging() {
        guard let ddProcess = ddProcess, ddProcess.isRunning else {
            print("Imaging process not running.")
            return
        }

        state = .cancelling 
        print("Stopping imaging process (PID: \(ddProcess.processIdentifier))...")
        ddProcess.interrupt()

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.ddProcess?.isRunning == true {
                print("Process still running, sending SIGKILL...")
                self?.ddProcess?.terminate() 
            }
        }
    }

     private func handleImagingCompletion(process: Process) {
         let exitCode = process.terminationStatus
         let reason = process.terminationReason
 
         errorPipe?.fileHandleForReading.readabilityHandler = nil
 
         if case .cancelling = state {
             print("Imaging process cancelled.")
             progress?.cancel()
             state = .idle
         } else if exitCode == 0 {
             print("Imaging process completed successfully.")
             progress?.completedUnitCount = progress?.totalUnitCount ?? 0 
             state = .completed
         } else {
             print("Imaging process failed. Exit code: \(exitCode), Reason: \(reason).")
             let errorData = errorPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
             if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                 print("dd stderr: \(errorString)")
             }
             state = .failed(ImagerError.processingInterrupted(reason: "dd process failed with exit code \(exitCode)"))
         }
 
         cleanupResources()
         let workItem = DispatchWorkItem {
             if case .completed = self.state {
                 self.state = .idle
             } else if case .cancelling = self.state { 
                 self.state = .idle
             } else if case .failed = self.state {
                 self.state = .idle
             }
         }
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem) 
     }

     private func parseDdProgress(_ output: String) {
         let lines = output.split(separator: "\r") 
         for line in lines {
             if let bytesString = line.split(separator: " ").first,
                let bytesCopied = Int64(bytesString) {

                 if Date().timeIntervalSince(lastProgressUpdate) > 0.1 { 
                      DispatchQueue.main.async { 
                         self.progress?.completedUnitCount = bytesCopied 
                          self.lastProgressUpdate = Date() 
                       }
                  }
             }
         }
     }

     private func cleanupResources() {
         errorPipe?.fileHandleForReading.readabilityHandler = nil
 
         try? imageFileHandle?.close()
         try? driveFileHandle?.close()
         try? outputPipe?.fileHandleForReading.close()
         try? outputPipe?.fileHandleForWriting.close()
         try? errorPipe?.fileHandleForReading.close()
         try? errorPipe?.fileHandleForWriting.close()

         imageFileHandle = nil
         driveFileHandle = nil
         outputPipe = nil
         errorPipe = nil
         ddProcess = nil
         progressObservation = nil 
         progressHandler = nil
     }

    // Deinitializer to ensure cleanup
    deinit {
        cleanupResources() 
        progressObservation = nil 
    }

    // --- Imager Protocol Implementation ---
    public func progress(_ handler: @escaping (Foundation.Progress, ImagerError?) -> Void) {
        self.progressHandler = handler
    }
}

#endif // os(macOS)