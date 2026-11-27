// swift-tools-version: 6.0
// The calculator behind math mode: pure parsing and evaluation, tested with `swift test`.
import PackageDescription

let package = Package(
    name: "Calculator",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Calculator", targets: ["Calculator"]),
    ],
    targets: [
        .target(name: "Calculator"),
        .testTarget(name: "CalculatorTests", dependencies: ["Calculator"]),
    ]
)
