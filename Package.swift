// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "MarkdownEngineLite",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MarkdownEngineLite",
            targets: ["MarkdownEngineLite"]
        )
    ],
    targets: [
        .target(
            name: "MarkdownEngineLite",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MarkdownEngineLiteTests",
            dependencies: ["MarkdownEngineLite"]
        )
    ]
)
