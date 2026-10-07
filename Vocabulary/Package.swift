// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Vocabulary",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "VocabularyDomain", targets: ["VocabularyDomain"]),
        .library(name: "VocabularyDI", targets: ["VocabularyDI"]),
        // For the app's navigation values only.
        .library(name: "VocabularyUI", targets: ["VocabularyUI"]),
        .library(name: "VocabularyTestSupport", targets: ["VocabularyTestSupport"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Dictionary"),
    ],
    targets: [
        .target(
            name: "VocabularyDomain",
            dependencies: [
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
            ]
        ),
        .target(
            name: "VocabularyData",
            dependencies: [
                "VocabularyDomain",
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CorePersistence", package: "Core"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
            ]
        ),
        .target(
            name: "VocabularyUI",
            dependencies: [
                "VocabularyDomain",
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "VocabularyDI",
            dependencies: [
                "VocabularyDomain", "VocabularyData", "VocabularyUI",
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "VocabularyTestSupport",
            dependencies: ["VocabularyDomain", .product(name: "DictionaryDomain", package: "Dictionary"), .product(name: "CoreDomain", package: "Core")],
            path: "TestSupport"
        ),
        .testTarget(
            name: "VocabularyTests",
            dependencies: [
                "VocabularyDomain", "VocabularyData", "VocabularyUI", "VocabularyDI", "VocabularyTestSupport",
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "DictionaryTestSupport", package: "Dictionary"),
                // The bundled HSK list, for the tests that install it into a real store.
                .product(name: "DictionaryDI", package: "Dictionary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CorePersistence", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
