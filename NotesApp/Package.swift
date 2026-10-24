// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesApp",
    platforms: [
        .iOS("27.0.1"),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotesApp",
            targets: ["NotesApp"]
        ),
    ],
    targets: [
        .target(
            name: "NotesApp",
            path: "NotesApp"
        ),
    ]
)
