/// Error types that can occur during the imaging process.
///
/// These errors represent various failure scenarios that might occur when
/// attempting to write an image file to a drive.
public enum ImagerError: Error, Sendable {
    /// The provided image file is invalid.
    ///
    /// This error occurs when the image file cannot be read or is in an unsupported format.
    /// Only ZIP, TAR, and IMG formats are supported.
    case invalidImageFile(reason: String)
    
    /// The selected drive is invalid.
    ///
    /// This error occurs when the specified drive cannot be used as a target.
    /// The associated value provides the operating system's specific reason for the failure.
    case invalidDrive(reason: String)
    
    /// Permission to access the drive was denied.
    ///
    /// This error occurs when the application does not have sufficient privileges
    /// to write to the selected drive. The associated value provides the operating
    /// system's specific reason for the permission denial.
    case permissionDenied(reason: String)
    
    /// The image file is too large for the selected drive.
    ///
    /// This error occurs when the size of the image file exceeds the available
    /// space on the target drive.
    case imageTooLargeForDrive(imageSize: UInt64, driveSize: UInt64)
    
    /// The imaging process was interrupted.
    ///
    /// This error occurs when the imaging process is unexpectedly terminated
    /// before completion. The associated value provides information about the
    /// cause of the interruption.
    case processingInterrupted(reason: String)
    
    /// Error detecting or enumerating drives.
    ///
    /// This error occurs when there is an issue detecting or enumerating drives.
    /// The associated value provides information about the cause of the error.
    case driveDetectionError(reason: String)
    
    /// Error related to disk watching functionality.
    ///
    /// This error occurs when setting up or managing DiskArbitration callbacks fails.
    case diskWatchError(reason: String)
    
    /// Functionality not implemented.
    ///
    /// This error occurs when a feature is not yet implemented for a particular platform.
    case notImplemented(reason: String)
    
    /// An unknown error occurred.
    ///
    /// This error represents any failure that doesn't fall into the other categories.
    /// It should be used as a last resort when the specific error type cannot be determined.
    case unknown(reason: String?)

}

// MARK: - CustomStringConvertible

extension ImagerError: CustomStringConvertible {
    /// A user-friendly description of the error.
    public var description: String {
        switch self {
        case .invalidImageFile(let reason):
            return "Invalid Image File: \(reason). Only ZIP, TAR, and IMG formats are supported."
            
        case .invalidDrive(let reason):
            return "Invalid drive: \(reason)"
            
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
            
        case .imageTooLargeForDrive(let imageSize, let driveSize):
            let imageSizeMB = Double(imageSize) / 1_048_576
            let driveSizeMB = Double(driveSize) / 1_048_576
            return "Image too large for drive: Image size is \(String(format: "%.1f", imageSizeMB)) MB, but drive size is only \(String(format: "%.1f", driveSizeMB)) MB"
            
        case .processingInterrupted(let reason):
            return "Imaging process was interrupted: \(reason)"
            
        case .driveDetectionError(let reason):
            return "Error detecting drives: \(reason)"
            
        case .diskWatchError(let reason):
            return "Disk Watch Error: \(reason)"
            
        case .notImplemented(let reason):
            return "Functionality not implemented: \(reason)"
            
        case .unknown(let reason):
            if let reason = reason, !reason.isEmpty {
                return "An unknown error occurred: \(reason)"
            } else {
                return "An unknown error occurred"
            }
        }
    }
}