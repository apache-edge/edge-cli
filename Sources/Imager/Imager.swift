import Foundation

/// Public typealias for disk update notifications, usable by consumers
public typealias DiskUpdateCallback = () -> Void

/// Protocol defining the interface for an image writer.
///
/// This protocol defines the requirements for a component that can write
/// an image file to a drive.
public protocol Imager {
    /// Path to the image file to be imaged.
    var imageFilePath: String { get }

    /// Path to the drive to be imaged.
    var drivePath: String { get }

    /// The current state of the imaging process.
    var state: ImagerState { get }

    /// Get a list of available drives that can be imaged in alphabetical order.
    ///
    /// - Parameter onlyExternalDrives: If true, only external drives will be returned.
    /// - Returns: An array of drive identifiers that can be used for imaging.
    /// - Throws: An `ImagerError` if the drives cannot be enumerated.
    func availableDrivesToImage(onlyExternalDrives: Bool) throws -> [Drive]

    /// Begin imaging the drive.
    /// 
    /// This method starts the process of writing the image file to the drive.
    /// It may throw an `ImagerError` if the operation cannot be completed.
    func startImaging() throws

    /// Stop the imaging process.
    ///
    /// This method stops the imaging process if it is currently running.
    /// It may throw an `ImagerError` if the operation cannot be stopped.
    func stopImaging() throws

    /// Register a handler to receive progress updates.
    ///
    /// - Parameter handler: A closure that will be called with progress updates.
    ///   The closure receives the current progress and an optional error if one occurred.
    func progress(_ handler: @escaping (Foundation.Progress, ImagerError?) -> Void)

    /// Initialize a new imager with the specified image file and drive paths.
    ///
    /// - Parameters:
    ///   - imageFilePath: The path to the image file to be written.
    ///   - drivePath: The path to the drive where the image will be written.
    init(imageFilePath: String, drivePath: String)
}