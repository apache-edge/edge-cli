#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

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
#if canImport(Foundation) || canImport(FoundationEssentials)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: capacity)
#else
        // Basic fallback for non-Apple platforms
        let kb = Double(capacity) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        if gb < 1024 {
            return String(format: "%.1f GB", gb)
        }
        let tb = gb / 1024.0
        return String(format: "%.1f TB", tb)
#endif
    }

    /// The available space on the drive in a human-readable format, or "N/A" if unknown.
    public var availableHumanReadable: String {
        guard let availableSpace = available else {
            return "N/A"
        }
#if canImport(Foundation) || canImport(FoundationEssentials)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: availableSpace)
#else
        // Basic fallback for non-Apple platforms
        let kb = Double(availableSpace) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        if gb < 1024 {
            return String(format: "%.1f GB", gb)
        }
        let tb = gb / 1024.0
        return String(format: "%.1f TB", tb)
#endif
    }
}
