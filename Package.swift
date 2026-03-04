// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AntiADHD",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AntiADHD", targets: ["AntiADHD"])
    ],
    targets: [
        .executableTarget(
            name: "AntiADHD"
        ),
        .testTarget(
            name: "AntiADHDTests",
            dependencies: ["AntiADHD"]
        )
    ]
)
