// swift-tools-version: 6.0
// The clipboard history behind clipboard mode: content fingerprints, de-duplication and storage.
import PackageDescription

let package = Package(
    name: "ClipboardHistory",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClipboardHistory", targets: ["ClipboardHistory"]),
    ],
    targets: [
        .target(name: "ClipboardHistory"),
        .testTarget(name: "ClipboardHistoryTests", dependencies: ["ClipboardHistory"]),
    ]
)
