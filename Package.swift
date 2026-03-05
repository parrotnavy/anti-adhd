// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AntiADHD",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AntiADHD", targets: ["AntiADHD"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AntiADHD",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "AntiADHDTests",
            dependencies: ["AntiADHD"]
        )
    ]
)
