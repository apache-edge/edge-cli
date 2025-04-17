#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct Drive {
    /// The path to the drive.
    var path: String
    /// The size of the drive in bytes.
    var size: Int64
    /// The name of the drive.
    var name: String?

    /// The size of the drive in a human-readable format.
    var sizeHumanReadable: String {
#if canImport(Foundation) || canImport(FoundationEssentials)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: size)
#else
        // Fallback implementation when ByteCountFormatter is not available
        let kb = Double(size) / 1024.0
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
