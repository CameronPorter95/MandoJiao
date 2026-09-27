// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Speaking",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SpeakingDomain", targets: ["SpeakingDomain"]),
        .library(name: "SpeakingDI", targets: ["SpeakingDI"]),
        // For the app's navigation values only.
        .library(name: "SpeakingUI", targets: ["SpeakingUI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Vocabulary"),
    ],
    targets: [
        .target(
            name: "SpeakingDomain",
            dependencies: [.product(name: "VocabularyDomain", package: "Vocabulary")]
        ),
        .target(
            name: "SpeakingData",
            dependencies: [
                "SpeakingDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
            ]
        ),
        .target(
            name: "SpeakingUI",
            dependencies: [
                "SpeakingDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "SpeakingDI",
            dependencies: [
                "SpeakingDomain", "SpeakingData", "SpeakingUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreSound", package: "Core"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "SpeakingTestSupport",
            dependencies: ["SpeakingDomain"],
            path: "TestSupport",
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "SpeakingTests",
            dependencies: [
                "SpeakingDomain", "SpeakingData", "SpeakingUI", "SpeakingTestSupport",
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
