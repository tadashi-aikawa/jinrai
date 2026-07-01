// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "jinrai-native",
    platforms: [.macOS(.v14)],
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
            path: "Sources/JinraiPlatform"
        ),
        // 実行ターゲット(メニューバー常駐アプリ)
        .executableTarget(
            name: "Jinrai",
            dependencies: ["JinraiPlatform"],
            path: "Sources/Jinrai"
        ),
        .testTarget(
            name: "JinraiCoreTests",
            dependencies: ["JinraiCore"],
            path: "Tests/JinraiCoreTests"
        ),
    ]
)
