import Foundation
import CryptoKit
import Shell

/// Builds a Docker-compatible container image from the given executable.
/// The image is saved to the given path.
///
/// This currently follows the format expected by `docker load`, which is not
/// the same as the OCI Image Format Specification.
public func buildContainer(
    architecture: String = "arm64",
    executable: URL,
    outputPath: String
) async throws {
    // TODO: Implement this using the OCI Image Format Specification instead of Docker's format?
    // TODO: Write directly to a tar file instead of using a temporary directory

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    let executableName = executable.lastPathComponent
    let imageName = executableName.lowercased()
    
    let layerDir = tempDir.appendingPathComponent("layer")
    try FileManager.default.createDirectory(at: layerDir, withIntermediateDirectories: true)
    
    // mkdir /bin
    let binDir = layerDir.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
    
    // cp executable /bin/executable
    let layerExecutable = binDir.appendingPathComponent(executableName)
    try FileManager.default.copyItem(at: executable, to: layerExecutable)
    
    // chmod 755 /bin/executable
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: layerExecutable.path)
    
    let layerTarPath = tempDir.appendingPathComponent("layer.tar")
    try await createTarball(from: layerDir, to: layerTarPath)
    
    // Calculate the SHA256 checksum of the layer tarball
    // TODO: Switch to NIOFilesystem instead of Data(contentsOf:)
    let layerData = try Data(contentsOf: layerTarPath)
    let layerSHA = sha256(data: layerData)
    
    // Create config.json
    let config = DockerConfig(
        architecture: architecture,
        created: ISO8601DateFormatter().string(from: Date()),
        os: "linux",
        config: ContainerConfig(
            Cmd: ["/bin/\(executableName)"],
            Env: ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"],
            WorkingDir: "/"
        ),
        rootfs: RootFS(
            type: "layers",
            diff_ids: ["sha256:\(layerSHA)"]
        )
    )
    
    // Serialize and save config
    let configData = try JSONEncoder().encode(config)
    let configPath = tempDir.appendingPathComponent("config.json")
    try configData.write(to: configPath)
    let configSHA = sha256(data: configData)
    
    // Create image manifest
    let imageTag = "latest"
    let repositories = [
        imageName: [
            imageTag: configSHA
        ]
    ]
    let repositoriesData = try JSONEncoder().encode(repositories)
    let repositoriesPath = tempDir.appendingPathComponent("repositories")
    try repositoriesData.write(to: repositoriesPath)
    
    // Create final container image tarball
    let imageDir = tempDir.appendingPathComponent("image")
    try FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
    
    // Copy layer and config to image directory
    let imageLayerPath = imageDir.appendingPathComponent("\(layerSHA).tar")
    try FileManager.default.copyItem(at: layerTarPath, to: imageLayerPath)
    
    let imageConfigPath = imageDir.appendingPathComponent("\(configSHA).json")
    try configData.write(to: imageConfigPath)
    
    // Copy repositories file to image directory
    let imageRepositoriesPath = imageDir.appendingPathComponent("repositories")
    try repositoriesData.write(to: imageRepositoriesPath)
    
    // manifest.json
    let manifest: [DockerManifestEntry] = [
        DockerManifestEntry(
            Config: "\(configSHA).json",
            RepoTags: ["\(imageName):\(imageTag)"],
            Layers: ["\(layerSHA).tar"]
        )
    ]
    
    let manifestData = try JSONEncoder().encode(manifest)
    let manifestPath = imageDir.appendingPathComponent("manifest.json")
    try manifestData.write(to: manifestPath)
    
    try await createTarball(from: imageDir, to: URL(fileURLWithPath: outputPath))

    try FileManager.default.removeItem(at: tempDir)
}

// Calculate SHA256 hash using CryptoKit
private func sha256(data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// Creates a tarball from the given source directory using /usr/bin/tar.
///
/// - Parameter sourceDir: The directory to create a tarball from.
/// - Parameter destinationURL: The URL to save the tarball to.
/// - Throws: An error if the tarball cannot be created.
private func createTarball(from sourceDir: URL, to destinationURL: URL) async throws {
    try await Shell.run(["/usr/bin/tar", "cf", destinationURL.path, "-C", sourceDir.path, "."])
}

struct ContainerConfig: Codable {
    var Cmd: [String]
    var Env: [String]
    var WorkingDir: String
}

struct RootFS: Codable {
    var type: String
    var diff_ids: [String]
}

struct DockerConfig: Codable {
    var architecture: String
    var created: String
    var os: String
    var config: ContainerConfig
    var rootfs: RootFS
}

struct DockerManifestEntry: Codable {
    var Config: String
    var RepoTags: [String]
    var Layers: [String]
}