// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

/// No domain or data of its own: the screen edits settings that the speaking and matching
/// lessons own, through their domains.
let package = Package(
    name: "Settings",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SettingsDI", targets: ["SettingsDI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Practice"),
        .package(path: "../Library"),
    ],
    targets: [
        .target(
            name: "SettingsUI",
            dependencies: [
                .product(name: "PracticeDomain", package: "Practice"),
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "SettingsDI",
            dependencies: [
                "SettingsUI",
                .product(name: "PracticeDomain", package: "Practice"),
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "SettingsTests",
            dependencies: [
                "SettingsUI",
                .product(name: "CoreUI", package: "Core"),
                .product(name: "PracticeDomain", package: "Practice"),
                .product(name: "LibraryDomain", package: "Library"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
