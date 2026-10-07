// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "MixedLesson",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MixedLessonDomain", targets: ["MixedLessonDomain"]),
        .library(name: "MixedLessonDI", targets: ["MixedLessonDI"]),
        // For the app's navigation values only.
        .library(name: "MixedLessonUI", targets: ["MixedLessonUI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Vocabulary"),
        .package(path: "../Flashcards"),
    ],
    targets: [
        .target(
            name: "MixedLessonDomain",
            dependencies: [
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "FlashcardsDomain", package: "Flashcards"),
            ]
        ),
        .target(
            name: "MixedLessonUI",
            dependencies: [
                "MixedLessonDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "MixedLessonDI",
            dependencies: [
                "MixedLessonDomain", "MixedLessonUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreSound", package: "Core"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "MixedLessonTests",
            dependencies: [
                "MixedLessonDomain", "MixedLessonUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "VocabularyTestSupport", package: "Vocabulary"),
                .product(name: "FlashcardsDomain", package: "Flashcards"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
