/// Represents the current state of the imaging process.
///
/// This enum tracks the lifecycle of an imaging operation, from initialization through
/// completion or failure, including progress updates during the process.
enum ImagerState {
    /// The imager is initialized but has not started imaging.
    ///
    /// This is the initial state before the imaging process begins.
    case idle
    
    /// The imaging process is actively running.
    ///
    /// This state indicates that data is being written to the target drive.
    case imaging
    
    /// The imaging process has successfully completed.
    ///
    /// This state indicates that all data has been successfully written to the target drive.
    case completed
    
    /// The imaging process has failed.
    ///
    /// This state includes an associated `ImagerError` value that provides
    /// detailed information about the cause of the failure.
    case failed(ImagerError)
    
    /// A progress update for the ongoing imaging process.
    ///
    /// This state includes a `Progress` value that contains information about
    /// the current progress of the imaging operation, including the total bytes,
    /// completed bytes, and percentage completion.
    case progress(Progress)
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