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
    ],
    targets: [
        .executableTarget(
            name: "MandoCLI",
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
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
