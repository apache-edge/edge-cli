#if os(macOS)
import Foundation
import DiskArbitration
import IOKit

/// Concrete implementation of the Imager protocol for macOS.
public struct MacOSDiskLister: DiskLister, @unchecked Sendable { 

    public init() {}

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
}

#endif // os(macOS)