import Foundation

/// Defines the interface for listing disk drives available for imaging.
public protocol DiskLister: Sendable {
    /// Retrieves a list of drives that can potentially be used as imaging targets.
    ///
    /// This function should identify physical drives connected to the system.
    ///
    /// - Parameter onlyExternalDrives: If `true`, only external drives (like USB drives)
    ///                                 are returned. If `false`, internal drives might also
    ///                                 be included.
    /// - Returns: An array of `Drive` objects representing the available drives.
    /// - Throws: An error if the drive list cannot be retrieved (e.g., permission issues).
    func availableDrivesToImage(onlyExternalDrives: Bool) throws -> [Drive]
}