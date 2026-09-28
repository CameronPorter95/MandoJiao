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
    ],
    targets: [
        .target(
            name: "VocabularyDomain",
            dependencies: [.product(name: "CoreDomain", package: "Core")]
        ),
        .target(
            name: "VocabularyData",
            dependencies: [
                "VocabularyDomain",
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CorePersistence", package: "Core"),
            ],
            resources: [.copy("Resources/Dictionary.tsv"), .copy("Resources/HSK.tsv")]
        ),
        .target(
            name: "VocabularyUI",
            dependencies: [
                "VocabularyDomain",
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
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "VocabularyTestSupport",
            dependencies: ["VocabularyDomain", .product(name: "CoreDomain", package: "Core")],
            path: "TestSupport"
        ),
        .testTarget(
            name: "VocabularyTests",
            dependencies: [
                "VocabularyDomain", "VocabularyData", "VocabularyUI", "VocabularyDI", "VocabularyTestSupport",
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CorePersistence", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            resources: [.copy("Fixtures/VocabularyV1.store"), .copy("Fixtures/VocabularyV3.store")],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
