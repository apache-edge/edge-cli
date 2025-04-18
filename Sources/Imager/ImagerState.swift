/// Represents the current status of the imaging process.
///
/// This enum tracks the lifecycle of an imaging operation, from initialization through
/// completion or failure.
public enum ImagerState {
    /// The imager is initialized but has not started imaging.
    ///
    /// This is the default state before `startImaging()` is called.
    case idle
    
    /// The imaging process has started but has not yet completed or failed.
    ///
    /// This state indicates that the operation is active.
    case imaging
    
    /// The imaging process is being cancelled.
    case cancelling
    
    /// The imaging process completed successfully.
    ///
    /// This state indicates that the image file was written to the drive without errors.
    case completed
    
    /// The imaging process failed.
    ///
    /// The associated value `ImagerError` provides details about the failure reason.
    case failed(ImagerError)
}

// MARK: - CustomStringConvertible

extension ImagerState: CustomStringConvertible {
    /// A user-friendly description of the current imaging state.
    public var description: String {
        switch self {
        case .idle:
            return "Ready to begin imaging"
            
        case .imaging:
            return "Imaging in progress"
            
        case .cancelling:
            return "Cancelling imaging process"
            
        case .completed:
            return "Imaging completed successfully"
            
        case .failed(let error):
            return "Imaging failed: \(error.localizedDescription)"
        }
    }
}