import Foundation

/// Provides factory methods for creating platform-specific Imager and DiskLister instances.
public struct ImagerFactory {

    /// Creates a platform-specific object conforming to the Imager protocol.
    /// - Parameters:
    ///   - imageFilePath: The path to the source image file.
    ///   - drivePath: The path to the target drive (e.g., "disk4").
    /// - Returns: An object conforming to Imager.
    public static func createImager(imageFilePath: String, drivePath: String) -> Imager {
        #if os(macOS)
        return MacOSImager(imageFilePath: imageFilePath, drivePath: drivePath)
        #elseif os(Linux)
        // return LinuxImager(imageFilePath: imageFilePath, drivePath: drivePath)
        fatalError("Linux implementation not yet available.")
        #else
        fatalError("Unsupported operating system.")
        #endif
    }

    /// Creates a platform-specific object conforming to the DiskLister protocol.
    /// - Returns: An object conforming to DiskLister.
    public static func createDiskLister() -> DiskLister {
        #if os(macOS)
        return MacOSDiskLister()
        #elseif os(Linux)
        // return LinuxDiskLister()
        fatalError("Linux implementation not yet available.")
        #else
        fatalError("Unsupported operating system.")
        #endif
    }
}
