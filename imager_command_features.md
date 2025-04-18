# Imager Command Features

## List Disk Subcommand

1. `edge-cli imager list-disks` should list available drives to image. The timeout option will default to 3 seconds. 
2. `edge-cli imager list-disks --watch` should list available drives to image and watch for changes. The user should able to press `q`, `esc` or `ctrl-c` to exit the watch mode.
3. `edge-cli imager list-disks --timeout <seconds>` should list available drives to image and prompt the user to select a drive to image. The command should exit after the specified timeout. 
4. `edge-cli imager list-disks --all` should list all available drives, including internal ones. This can be used with `--watch` and `--timeout` options.

## Image Subcommand

1. `edge-cli imager image --source <path_to_image_file> --target <path_to_drive>` should image the specified drive with the specified image file. It will print progress to the console. If there is an error, it will print the `ImagerError` from the `Imager` package's description and exit with a non-zero code. 
2. The progress bar should be displayed in the console with ASCII characters using █ for filled and ░ for empty.

Example: [█████░░░░░] to represent 50% progress.
