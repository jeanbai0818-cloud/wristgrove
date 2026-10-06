// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WristGroveCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [.library(name: "WristGroveCore", targets: ["WristGroveCore"])],
    targets: [
        .target(name: "WristGroveCore"),
        .testTarget(name: "WristGroveCoreTests", dependencies: ["WristGroveCore"])
    ]
)
