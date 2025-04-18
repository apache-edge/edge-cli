import ArgumentParser
import Foundation
import Imager
#if canImport(Darwin)
import Darwin // For signal handling
#endif

struct ImagerListDisksSubCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "list-disks",
        abstract: "Lists available drives that can be targeted for imaging."
    )

    @Flag(name: .long, help: "Include internal drives in the list.")
    var all: Bool = false

    // Note: Timeout functionality is not implemented yet.
    @Option(name: .long, help: "Timeout in seconds (functionality not yet implemented).")
    var timeout: Int?

    func run() async throws {
        let imager = ImagerFactory.createImager()
        try await MainActor.run {
            try listAndPrintDisks(imager: imager, listAll: self.all)
        }
    }

    @MainActor
    private func listAndPrintDisks(imager: Imager, listAll: Bool) throws {
        let drives = try imager.availableDrivesToImage(onlyExternalDrives: !listAll)

        if drives.isEmpty {
            print(listAll ? "No drives found." : "No suitable external drives found. Use --all to list internal drives.")
            fflush(stdout)
            return
        }

        let nameHeader = "Name"
        let pathHeader = "Path"
        let availableHeader = "Available"
        let capacityHeader = "Capacity"

        let maxNameWidth = drives.map { $0.name?.count ?? "(No Name)".count }.max() ?? nameHeader.count
        let maxPathWidth = drives.map { $0.path.count }.max() ?? pathHeader.count
        let maxAvailableWidth = drives.map { $0.availableHumanReadable.count }.max() ?? availableHeader.count
        let maxCapacityWidth = drives.map { $0.capacityHumanReadable.count }.max() ?? capacityHeader.count

        let header = "\(nameHeader.padding(toLength: maxNameWidth, withPad: " ", startingAt: 0))  \(pathHeader.padding(toLength: maxPathWidth, withPad: " ", startingAt: 0))  \(availableHeader.padding(toLength: maxAvailableWidth, withPad: " ", startingAt: 0))  \(capacityHeader.padding(toLength: maxCapacityWidth, withPad: " ", startingAt: 0))"
        print(header)
        print(String(repeating: "-", count: header.count))

        for drive in drives {
            let name = (drive.name ?? "(No Name)").padding(toLength: maxNameWidth, withPad: " ", startingAt: 0)
            let path = drive.path.padding(toLength: maxPathWidth, withPad: " ", startingAt: 0)
            let available = drive.availableHumanReadable.padding(toLength: maxAvailableWidth, withPad: " ", startingAt: 0)
            let capacity = drive.capacityHumanReadable.padding(toLength: maxCapacityWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(path)  \(available)  \(capacity)")
        }
        fflush(stdout) // Flush after printing the table
    }
}