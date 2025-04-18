import Foundation

/// Defines the interface for an object capable of writing an image file to a drive.
public protocol Imager: Sendable {
    /// The path to the source image file.
    var imageFilePath: String { get }
    
    /// The path to the target drive (e.g., "disk4" on macOS).
    var drivePath: String { get }

    /// Initializes the Imager with the necessary paths.
    /// - Parameters:
    ///   - imageFilePath: The full path to the source image file.
    ///   - drivePath: The identifier for the target drive (e.g., "disk4").
    init(imageFilePath: String, drivePath: String)
    
    /// Starts the imaging process.
    ///
    /// This method performs the actual writing of the image file to the target drive.
    /// It should handle necessary pre-checks (like drive mounting status) and execute
    /// the underlying imaging command (e.g., `dd`).
    ///
    /// - Parameter handler: A closure that is called periodically with progress updates
    ///                        and upon completion or failure.
    func startImaging(handler: @Sendable @escaping (_ progress: Progress, _ error: ImagerError?) -> Void)
}
