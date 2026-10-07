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
        .package(path: "../Vocabulary"),
    ],
    targets: [
        .target(
            name: "PracticeDomain",
            dependencies: [.product(name: "VocabularyDomain", package: "Vocabulary")]
        ),
        .target(
            name: "PracticeData",
            dependencies: [
                "PracticeDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
            ]
        ),
        .target(
            name: "PracticeUI",
            dependencies: [
                "PracticeDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "PracticeDI",
            dependencies: [
                "PracticeDomain", "PracticeData", "PracticeUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
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
                "PracticeDomain", "PracticeData", "PracticeUI", "PracticeTestSupport",
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
