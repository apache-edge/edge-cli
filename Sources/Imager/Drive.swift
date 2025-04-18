import Foundation
/// A structure representing a drive. 
public struct Drive {
    /// The path to the drive.
    public var path: String
    /// The total capacity of the drive in bytes.
    public var capacity: Int64
    /// The available free space on the drive in bytes, if known.
    public var available: Int64?
    /// The name of the drive.
    public var name: String?

    /// The total capacity of the drive in a human-readable format.
    public var capacityHumanReadable: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: capacity)
    }

    /// The available space on the drive in a human-readable format, or "N/A" if unknown.
    public var availableHumanReadable: String {
        guard let availableSpace = available else {
            return "N/A"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: availableSpace)
    }
}
