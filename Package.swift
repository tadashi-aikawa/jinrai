// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "jinrai",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Command Line Tools のみの環境には swift-testing が同梱されないため依存で供給
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        // 非公開 CGS / AX API の extern 宣言のみを持つ C ターゲット
        .target(
            name: "CGSPrivate",
            path: "Sources/CGSPrivate"
        ),
        // 純粋ロジック層(Foundation + CoreGraphics の値型のみ。ユニットテストの主戦場)
        .target(
            name: "JinraiCore",
            path: "Sources/JinraiCore"
        ),
        // macOS API 層(AppKit / ApplicationServices / Carbon)
        .target(
            name: "JinraiPlatform",
            dependencies: ["JinraiCore", "CGSPrivate"],
            path: "Sources/JinraiPlatform",
            linkerSettings: [
                // SLPS* (window server 経由のフォーカス) は SkyLight.framework にのみ実体がある
                .unsafeFlags([
                    "-F", "/System/Library/PrivateFrameworks",
                    "-framework", "SkyLight",
                ])
            ]
        ),
        // 実行ターゲット(メニューバー常駐アプリ)
        .executableTarget(
            name: "JINRAI",
            dependencies: ["JinraiPlatform"],
            path: "Sources/Jinrai"
        ),
        .testTarget(
            name: "JinraiCoreTests",
            dependencies: [
                "JinraiCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/JinraiCoreTests"
        ),
    ]
)
