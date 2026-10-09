// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; this builds both.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

/// Every screen's input, built once for the app and for mando. Not a feature package: it is
/// the composition root's, the one place that sees every package's DI.
let package = Package(
    name: "AppComposition",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AppComposition", targets: ["AppComposition"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Library"),
        .package(path: "../Dictionary"),
        .package(path: "../Practice"),
        .package(path: "../Progress"),
        .package(path: "../Settings"),
    ],
    targets: [
        .target(
            name: "AppComposition",
            dependencies: [
                .product(name: "CoreDI", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "LibraryDI", package: "Library"),
                .product(name: "LibraryUI", package: "Library"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "DictionaryDI", package: "Dictionary"),
                .product(name: "PracticeDomain", package: "Practice"),
                .product(name: "PracticeDI", package: "Practice"),
                .product(name: "ProgressDomain", package: "Progress"),
                .product(name: "ProgressDI", package: "Progress"),
                .product(name: "SettingsDI", package: "Settings"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "AppCompositionTests",
            dependencies: [
                "AppComposition",
                .product(name: "CoreTestSupport", package: "Core"),
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "PracticeDI", package: "Practice"),
                .product(name: "ProgressDomain", package: "Progress"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
