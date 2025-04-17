struct Progress {
    /// The total number of bytes to be written.
    var totalBytes: Int64
    
    /// The number of bytes that have been written.
    var completedBytes: Int64
    
    /// The percentage of the image that has been written.
    var percentage: Double {
        return Double(completedBytes) / Double(totalBytes)
    }
}