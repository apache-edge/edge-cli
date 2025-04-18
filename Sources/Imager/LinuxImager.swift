#if os(Linux)
import Foundation

/// Concrete implementation of the Imager protocol for Linux.
public class LinuxImager: Imager, @unchecked Sendable {
    public let imageFilePath: String
    public let drivePath: String
    public var state: ImagerState = .idle
    private var progress: Foundation.Progress?
    private var progressHandler: ((Foundation.Progress, ImagerError?) -> Void)?
    
    private var ddProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    public required init(imageFilePath: String = "", drivePath: String = "") {
        self.imageFilePath = imageFilePath
        self.drivePath = drivePath
        self.progress = Progress(totalUnitCount: 0)
    }
    
    public func availableDrivesToImage(onlyExternalDrives: Bool) throws -> [Drive] {
        // Implementation for Linux would use commands like lsblk to list block devices
        // For now, return an empty array
        return []
    }
    
    public func startImaging() throws {
        // Implementation would use dd command similar to MacOSImager
        throw ImagerError.notImplemented(reason: "Linux imaging not yet implemented")
    }
    
    public func stopImaging() throws {
        // Implementation would stop the dd process
        throw ImagerError.notImplemented(reason: "Linux imaging not yet implemented")
    }
    
    public func progress(_ handler: @escaping (Foundation.Progress, ImagerError?) -> Void) {
        self.progressHandler = handler
    }
}
#endif // os(Linux)