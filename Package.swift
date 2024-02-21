// swift-tools-version:5.3

import PackageDescription

/// The Package
public let package = Package(
    name: "HAKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v16),
        .watchOS(.v5),
    ],
    products: [
        .library(
            name: "HAKit",
            targets: ["HAKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/mxcl/PromiseKit",
            from: "6.13.2"
        ),
    ],
    targets: [
        .target(
            name: "HAKit",
            dependencies: [ ],
            path: "Source"
        ),
        .target(
            name: "HAKit+PromiseKit",
            dependencies: [
                .byName(name: "HAKit"),
                .byName(name: "PromiseKit"),
            ],
            path: "Extensions/PromiseKit"
        ),
        .target(
            name: "HAKit+Mocks",
            dependencies: [
                .byName(name: "HAKit"),
            ],
            path: "Extensions/Mocks"
        ),
        .testTarget(
            name: "Tests",
            dependencies: [
                .byName(name: "HAKit"),
                .byName(name: "HAKit+PromiseKit"),
                .byName(name: "HAKit+Mocks"),
            ],
            path: "Tests"
        ),
    ]
)
