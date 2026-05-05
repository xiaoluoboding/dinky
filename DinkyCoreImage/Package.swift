// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DinkyCoreImage",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "DinkyCoreShared", targets: ["DinkyCoreShared"]),
        .library(name: "DinkyCoreImage", targets: ["DinkyCoreImage"]),
        .library(name: "DinkyCoreVideo", targets: ["DinkyCoreVideo"]),
        .library(name: "DinkyCoreAudio", targets: ["DinkyCoreAudio"]),
        .library(name: "DinkyCorePDF", targets: ["DinkyCorePDF"]),
        .library(name: "DinkyCLILib", targets: ["DinkyCLILib"]),
        .executable(name: "dinky", targets: ["DinkyCLIApp"]),
    ],
    targets: [
        .target(
            name: "DinkyCoreShared",
            path: "Sources/DinkyCoreShared"
        ),
        .target(
            name: "DinkyCoreImage",
            dependencies: ["DinkyCoreShared"],
            path: "Sources/DinkyCoreImage"
        ),
        .target(
            name: "DinkyCoreVideo",
            dependencies: ["DinkyCoreShared", "DinkyCoreImage"],
            path: "Sources/DinkyCoreVideo"
        ),
        .target(
            name: "DinkyCoreAudio",
            dependencies: ["DinkyCoreShared"],
            path: "Sources/DinkyCoreAudio"
        ),
        .target(
            name: "DinkyCorePDF",
            dependencies: ["DinkyCoreShared", "DinkyCoreImage"],
            path: "Sources/DinkyCorePDF"
        ),
        .target(
            name: "DinkyCLILib",
            dependencies: [
                "DinkyCoreShared",
                "DinkyCoreImage",
                "DinkyCoreVideo",
                "DinkyCoreAudio",
                "DinkyCorePDF",
            ],
            path: "Sources/DinkyCLILib"
        ),
        .executableTarget(
            name: "DinkyCLIApp",
            dependencies: ["DinkyCLILib"],
            path: "Sources/DinkyCLIApp"
        ),
        .testTarget(
            name: "DinkyCLILibTests",
            dependencies: ["DinkyCLILib", "DinkyCoreImage", "DinkyCoreVideo", "DinkyCoreAudio", "DinkyCorePDF", "DinkyCoreShared"],
            path: "Tests/DinkyCLILibTests"
        ),
    ]
)
