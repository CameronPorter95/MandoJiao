// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

/// Reference data the learner did not write: CC-CEDICT, the HSK syllabus and the lexicon,
/// with the dictionary tab and word page. Knows nothing of the library; whether a reading is
/// saved, and the editor that saves it, are handed in by the app.
let package = Package(
    name: "Dictionary",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "DictionaryDomain", targets: ["DictionaryDomain"]),
        .library(name: "DictionaryDI", targets: ["DictionaryDI"]),
        // For the app's navigation values only.
        .library(name: "DictionaryUI", targets: ["DictionaryUI"]),
        .library(name: "DictionaryTestSupport", targets: ["DictionaryTestSupport"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "DictionaryDomain",
            dependencies: [.product(name: "CoreDomain", package: "Core")]
        ),
        .target(
            name: "DictionaryData",
            dependencies: [
                "DictionaryDomain",
                .product(name: "CoreDomain", package: "Core"),
            ],
            resources: [.copy("Resources/Dictionary.tsv"), .copy("Resources/HSK.tsv")]
        ),
        .target(
            name: "DictionaryUI",
            dependencies: [
                "DictionaryDomain",
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "DictionaryDI",
            dependencies: [
                "DictionaryDomain", "DictionaryData", "DictionaryUI",
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "DictionaryTestSupport",
            dependencies: ["DictionaryDomain", .product(name: "CoreDomain", package: "Core")],
            path: "TestSupport"
        ),
        .testTarget(
            name: "DictionaryTests",
            dependencies: [
                "DictionaryDomain", "DictionaryData", "DictionaryUI", "DictionaryTestSupport",
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
