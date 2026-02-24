// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenCapture",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "ScreenCaptureLib",
            path: "Sources/ScreenCapture",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "ScreenCapture",
            dependencies: ["ScreenCaptureLib"],
            path: "Sources/ScreenCaptureApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "ScreenCaptureTests",
            dependencies: ["ScreenCaptureLib"],
            path: "Tests/ScreenCaptureTests"
        )
    ]
)
