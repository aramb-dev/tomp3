// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "tomp3",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "tomp3", targets: ["tomp3"]),
    .library(name: "ToMP3Core", targets: ["ToMP3Core"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.3.0"
    ),
  ],
  targets: [
    // Shared core — used by both the CLI and the Xcode app
    .target(
      name: "ToMP3Core",
      path: "Sources/ToMP3Core"
    ),

    // CLI executable
    .executableTarget(
      name: "tomp3",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "ToMP3Core",
      ],
      path: "Sources/tomp3"
    ),
  ]
)
