// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Matching",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "MatchingDomain", targets: ["MatchingDomain"]),
        .library(name: "MatchingDI", targets: ["MatchingDI"]),
        // For the app's navigation values only.
        .library(name: "MatchingUI", targets: ["MatchingUI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Vocabulary"),
    ],
    targets: [
        .target(
            name: "MatchingDomain",
            dependencies: [.product(name: "VocabularyDomain", package: "Vocabulary")]
        ),
        .target(
            name: "MatchingData",
            dependencies: [
                "MatchingDomain",
                .product(name: "CoreDomain", package: "Core"),
            ]
        ),
        .target(
            name: "MatchingUI",
            dependencies: [
                "MatchingDomain",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "MatchingDI",
            dependencies: [
                "MatchingDomain", "MatchingData", "MatchingUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "CoreDI", package: "Core"),
                .product(name: "CoreSound", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "MatchingTests",
            dependencies: [
                "MatchingDomain", "MatchingData", "MatchingUI",
                .product(name: "VocabularyDomain", package: "Vocabulary"),
                .product(name: "VocabularyTestSupport", package: "Vocabulary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v5]
)
