// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

/// Practising words: every exercise, and the mixed lesson that runs them together. Each
/// exercise is a folder in each target rather than a package of its own.
let package = Package(
    name: "Practice",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PracticeDomain", targets: ["PracticeDomain"]),
        .library(name: "PracticeDI", targets: ["PracticeDI"]),
        // For the app's navigation values only.
        .library(name: "PracticeUI", targets: ["PracticeUI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Library"),
        .package(path: "../Dictionary"),
        .package(path: "../Progress"),
    ],
    targets: [
        .target(
            name: "PracticeDomain",
            dependencies: [
                .product(name: "LibraryDomain", package: "Library"),
                // Gloss, to read a typed answer as a meaning is written.
                .product(name: "DictionaryDomain", package: "Dictionary"),
                // TodayPlan, which the mixed lesson runs.
                .product(name: "ProgressDomain", package: "Progress"),
            ]
        ),
        .target(
            name: "PracticeData",
            dependencies: [
                "PracticeDomain",
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "CoreDomain", package: "Core"),
            ]
        ),
        .target(
            name: "PracticeUI",
            dependencies: [
                "PracticeDomain",
                .product(name: "LibraryDomain", package: "Library"),
                // Example sentences for the teach step.
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "PracticeDI",
            dependencies: [
                .product(name: "ProgressDomain", package: "Progress"),
                "PracticeDomain", "PracticeData", "PracticeUI",
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreSound", package: "Core"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "PracticeTestSupport",
            dependencies: ["PracticeDomain"],
            path: "TestSupport",
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "PracticeTests",
            dependencies: [
                .product(name: "ProgressDomain", package: "Progress"),
                "PracticeDomain", "PracticeData", "PracticeUI", "PracticeDI", "PracticeTestSupport",
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "LibraryTestSupport", package: "Library"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
