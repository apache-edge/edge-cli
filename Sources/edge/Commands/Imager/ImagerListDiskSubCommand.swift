import Imager
import ArgumentParser
import Foundation

struct ImagerListDisksSubCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-disks",
        abstract: "List available drives to image."
    )

    @Flag(name: .long, help: "Shows both internal and external drives.")
    var all: Bool = false

    @Option(name: [.long, .customShort("t")], help: "The timeout in seconds.")
    var timeout: Int = 3

    func run() async throws {
        let imager = MacOSImager(imageFilePath: "", drivePath: "")
        let drives = try imager.availableDrivesToImage(onlyExternalDrives: !all)

        if drives.isEmpty {
            print(all ? "No drives found." : "No suitable external drives found. Use --all to list internal drives.")
            return
        }

        // Headers
        let nameHeader = "Name"
        let pathHeader = "Path"
        let availableHeader = "Available"
        let capacityHeader = "Capacity"

        // Calculate column widths
        let maxNameWidth = drives.map { $0.name?.count ?? "(No Name)".count }.max() ?? nameHeader.count
        let maxPathWidth = drives.map { $0.path.count }.max() ?? pathHeader.count
        let maxAvailableWidth = drives.map { $0.availableHumanReadable.count }.max() ?? availableHeader.count
        let maxCapacityWidth = drives.map { $0.capacityHumanReadable.count }.max() ?? capacityHeader.count

        // Print header
        let header = "\(nameHeader.padding(toLength: maxNameWidth, withPad: " ", startingAt: 0))  \(pathHeader.padding(toLength: maxPathWidth, withPad: " ", startingAt: 0))  \(availableHeader.padding(toLength: maxAvailableWidth, withPad: " ", startingAt: 0))  \(capacityHeader.padding(toLength: maxCapacityWidth, withPad: " ", startingAt: 0))"
        print(header)
        print(String(repeating: "-", count: header.count))

        // Print rows
        for drive in drives {
            let name = (drive.name ?? "(No Name)").padding(toLength: maxNameWidth, withPad: " ", startingAt: 0)
            let path = drive.path.padding(toLength: maxPathWidth, withPad: " ", startingAt: 0)
            let available = drive.availableHumanReadable.padding(toLength: maxAvailableWidth, withPad: " ", startingAt: 0)
            let capacity = drive.capacityHumanReadable.padding(toLength: maxCapacityWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(path)  \(available)  \(capacity)")
        }
    }
}