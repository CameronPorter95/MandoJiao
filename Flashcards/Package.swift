// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Flashcards",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FlashcardsDomain", targets: ["FlashcardsDomain"]),
        .library(name: "FlashcardsDI", targets: ["FlashcardsDI"]),
        // For the app's navigation values only.
        .library(name: "FlashcardsUI", targets: ["FlashcardsUI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Vocabulary"),
    ],
    targets: [
        .target(
            name: "FlashcardsDomain",
            dependencies: [.product(name: "VocabularyDomain", package: "Vocabulary")]
        ),
        .target(
            name: "FlashcardsUI",
            dependencies: [
                "FlashcardsDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "FlashcardsDI",
            dependencies: [
                "FlashcardsDomain", "FlashcardsUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "FlashcardsTests",
            dependencies: [
                "FlashcardsDomain", "FlashcardsUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "VocabularyTestSupport", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
