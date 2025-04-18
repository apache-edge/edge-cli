import Foundation

/// Factory methods for creating the appropriate Imager implementation for the current platform.
public enum ImagerFactory {
    /// Creates an Imager instance appropriate for the current platform.
    ///
    /// - Parameters:
    ///   - imageFilePath: The path to the image file to be written.
    ///   - drivePath: The path to the drive where the image will be written.
    /// - Returns: An Imager instance for the current platform.
    public static func createImager(imageFilePath: String = "", drivePath: String = "") -> Imager {
        #if os(macOS)
        return MacOSImager(imageFilePath: imageFilePath, drivePath: drivePath)
        #elseif os(Linux)
        return LinuxImager(imageFilePath: imageFilePath, drivePath: drivePath)
        #else
        fatalError("Unsupported platform")
        #endif
    }
}