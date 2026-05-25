// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "tomp3",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.3.0"
    ),
  ],
  targets: [
    .executableTarget(
      name: "tomp3",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/tomp3"
    ),
  ]
)
