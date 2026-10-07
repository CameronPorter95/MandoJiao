// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Library",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LibraryDomain", targets: ["LibraryDomain"]),
        .library(name: "LibraryDI", targets: ["LibraryDI"]),
        // For the app's navigation values only.
        .library(name: "LibraryUI", targets: ["LibraryUI"]),
        .library(name: "LibraryTestSupport", targets: ["LibraryTestSupport"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Dictionary"),
    ],
    targets: [
        .target(
            name: "LibraryDomain",
            dependencies: [
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
            ]
        ),
        .target(
            name: "LibraryData",
            dependencies: [
                "LibraryDomain",
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CorePersistence", package: "Core"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
            ]
        ),
        .target(
            name: "LibraryUI",
            dependencies: [
                "LibraryDomain",
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreDesignSystem", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "LibraryDI",
            dependencies: [
                "LibraryDomain", "LibraryData", "LibraryUI",
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "CoreDI", package: "Core"),
            ],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "LibraryTestSupport",
            dependencies: ["LibraryDomain", .product(name: "DictionaryDomain", package: "Dictionary"), .product(name: "CoreDomain", package: "Core")],
            path: "TestSupport"
        ),
        .testTarget(
            name: "LibraryTests",
            dependencies: [
                "LibraryDomain", "LibraryData", "LibraryUI", "LibraryDI", "LibraryTestSupport",
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
