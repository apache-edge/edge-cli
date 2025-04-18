import Foundation

/// A simple CLI progress bar that displays progress using ASCII block characters.
public struct ProgressBar {
    /// The width of the progress bar in characters.
    private let width: Int
    
    /// The character used for filled portions of the progress bar.
    private let filledChar: Character
    
    /// The character used for empty portions of the progress bar.
    private let emptyChar: Character
    
    /// The left bracket character.
    private let leftBracket: Character
    
    /// The right bracket character.
    private let rightBracket: Character
    
    /// Creates a new progress bar with the specified configuration.
    /// - Parameters:
    ///   - width: The width of the progress bar in characters. Default is 10.
    ///   - filledChar: The character used for filled portions. Default is "█".
    ///   - emptyChar: The character used for empty portions. Default is "░".
    ///   - leftBracket: The left bracket character. Default is "[".
    ///   - rightBracket: The right bracket character. Default is "]".
    public init(
        width: Int = 10,
        filledChar: Character = "█",
        emptyChar: Character = "░",
        leftBracket: Character = "[",
        rightBracket: Character = "]"
    ) {
        self.width = width
        self.filledChar = filledChar
        self.emptyChar = emptyChar
        self.leftBracket = leftBracket
        self.rightBracket = rightBracket
    }
    
    /// Renders the progress bar as a string based on the given progress value.
    /// - Parameter progress: A value between 0.0 and 1.0 representing the progress.
    /// - Returns: A string representation of the progress bar.
    public func render(progress: Double, additionalText: String? = nil) -> String {
        let clampedProgress = min(1.0, max(0.0, progress))
        let filledWidth = Int(Double(width) * clampedProgress)
        let emptyWidth = width - filledWidth
        
        let filledPart = String(repeating: filledChar, count: filledWidth)
        let emptyPart = String(repeating: emptyChar, count: emptyWidth)
        
        return "\(leftBracket)\(filledPart)\(emptyPart)\(rightBracket) \(additionalText ?? "")"
    }
    
    /// Renders the progress bar with a percentage value.
    /// - Parameter progress: A value between 0.0 and 1.0 representing the progress.
    /// - Returns: A string representation of the progress bar with percentage.
    public func renderWithPercentage(progress: Double, additionalText: String? = nil) -> String {
        let percentage = Int(min(1.0, max(0.0, progress)) * 100)
        return "\(render(progress: progress)) \(percentage)% \(additionalText ?? "")"
    }
    
    /// Updates the progress bar in place by clearing the current line and printing the new progress.
    /// - Parameters:
    ///   - progress: A value between 0.0 and 1.0 representing the progress.
    ///   - showPercentage: Whether to show the percentage value. Default is true.
    ///   - stream: The output stream to write to. Default is stdout.
    public func update(
        progress: Double,
        showPercentage: Bool = true,
        stream: UnsafeMutablePointer<FILE> = stdout,
        additionalText: String? = nil
    ) {
        // Clear the current line and move cursor to beginning
        fputs("\r\u{1B}[2K", stream)
        
        // Print the progress bar
        let progressBar = showPercentage ? renderWithPercentage(progress: progress, additionalText: additionalText) : render(progress: progress, additionalText: additionalText)
        fputs("\r\(progressBar)", stream)
        fflush(stream)
    }
    
    /// Completes the progress bar by setting it to 100% and adding a newline.
    /// - Parameters:
    ///   - message: An optional message to display after completing the progress.
    ///   - stream: The output stream to write to. Default is stdout.
    public func complete(
        message: String? = nil,
        stream: UnsafeMutablePointer<FILE> = stdout,
        additionalText: String? = nil
    ) {
        update(progress: 1.0, stream: stream, additionalText: additionalText)
        
        if let message = message {
            fputs("\n\(message)\n", stream)
        } else {
            fputs("\n", stream)
        }
    }
}
