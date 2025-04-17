public struct Progress {
    /// The total number of bytes to be written.
    public var totalBytes: Int64
    
    /// The number of bytes that have been written.
    public var completedBytes: Int64
    
    /// The percentage of the image that has been written.
    public var percentage: Double {
        return Double(completedBytes) / Double(totalBytes)
    }
}