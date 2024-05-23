// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "YaMulticast",
  platforms: [.macOS(.v10_15), .iOS(.v13)],
  products: [
    .library(
      name: "YaMulticast",
      targets: ["YaMulticast"]
    ),
  ],
  targets: [
    .target(
      name: "YaMulticast",
      path: "Sources",
      swiftSettings: [.define("INTERNAL_BUILD", .when(configuration: .debug))]
    ),
    .testTarget(
      name: "YaMulticastTests",
      dependencies: ["YaMulticast"],
      path: "Tests"
    ),
  ]
)
