// swift-tools-version: 6.2
import PackageDescription

/// `mando`: drives the app's screens on a Mac with no simulator. See
/// Documentation/headless-cli.md.
let package = Package(
    name: "MandoCLI",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "mando", targets: ["MandoCLI"]),
    ],
    dependencies: [
        .package(path: "../../Core"),
        .package(path: "../../Library"),
        .package(path: "../../Dictionary"),
        .package(path: "../../Practice"),
        .package(path: "../../Progress"),
    ],
    targets: [
        .executableTarget(
            name: "MandoCLI",
            dependencies: ["MandoKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // The commands, apart from reading stdin, so tests can run them in-process.
        .target(
            name: "MandoKit",
            dependencies: [
                .product(name: "CoreDI", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "LibraryDI", package: "Library"),
                .product(name: "LibraryUI", package: "Library"),
                .product(name: "DictionaryDI", package: "Dictionary"),
                .product(name: "PracticeDomain", package: "Practice"),
                .product(name: "PracticeDI", package: "Practice"),
                .product(name: "PracticeUI", package: "Practice"),
                .product(name: "PracticeTestSupport", package: "Practice"),
                .product(name: "ProgressDomain", package: "Progress"),
                .product(name: "ProgressDI", package: "Progress"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "MandoKitTests",
            dependencies: ["MandoKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
