import ArgumentParser
import Imager

struct ImagerCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "imager",
        abstract: "Commands for listing available disks and writing OS images to drives.",
        subcommands: [
            ImagerListDisksSubCommand.self,
            ImagerImageDiskSubCommand.self
        ]
    )
}
