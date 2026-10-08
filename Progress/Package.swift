// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

/// What to do next and how it is going: Home and today's plan, and later streaks, goals and
/// rewards. Reads the library through its domain; the library's use cases are handed in by
/// the app.
let package = Package(
    name: "Progress",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "ProgressDomain", targets: ["ProgressDomain"]),
        .library(name: "ProgressDI", targets: ["ProgressDI"]),
        // For the app's navigation values only.
        .library(name: "ProgressUI", targets: ["ProgressUI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Library"),
    ],
    targets: [
        .target(
            name: "ProgressDomain",
            dependencies: [.product(name: "LibraryDomain", package: "Library")]
        ),
        .target(
            name: "ProgressUI",
            dependencies: [
                "ProgressDomain",
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "ProgressDI",
            dependencies: [
                "ProgressDomain", "ProgressUI",
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "ProgressTests",
            dependencies: [
                "ProgressDomain", "ProgressUI", "ProgressDI",
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "LibraryTestSupport", package: "Library"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreTestSupport", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
