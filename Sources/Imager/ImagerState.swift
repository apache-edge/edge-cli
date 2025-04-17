/// Represents the current status of the imaging process.
///
/// This enum tracks the lifecycle of an imaging operation, from initialization through
/// completion or failure, including progress updates during the process.
public enum ImagerState {
    /// The imager is initialized but has not started imaging.
    ///
    /// This is the default state before `startImaging()` is called.
    case idle
    
    /// The imaging process is currently in progress.
    ///
    /// The associated value `Progress` provides details about the current progress,
    /// such as bytes written and total bytes.
    case progress(Progress)
    
    /// The imaging process has started but has not yet completed or failed.
    ///
    /// This state indicates that the operation is active.
    case imaging
    
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
            
        case .completed:
            return "Imaging completed successfully"
            
        case .failed(let error):
            return "Imaging failed: \(error)"
            
        case .progress(let progress):
            let percentage = Int(progress.percentage * 100)
            let completedMB = Double(progress.completedBytes) / 1_048_576
            let totalMB = Double(progress.totalBytes) / 1_048_576
            return "Progress: \(percentage)% (\(String(format: "%.1f", completedMB)) MB of \(String(format: "%.1f", totalMB)) MB)"
        }
    }
}