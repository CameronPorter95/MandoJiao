// swift-tools-version: 6.2
import PackageDescription

/// `review-examples`: runs the app's on-device example writer over every word that would ask
/// for one, on a Mac with Apple Intelligence, and writes what it wrote for review. See
/// Documentation/exercises.md.
let package = Package(
    name: "ExampleReview",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "review-examples", targets: ["ExampleReview"]),
    ],
    dependencies: [
        .package(path: "../../Library"),
        .package(path: "../../Dictionary"),
    ],
    targets: [
        .executableTarget(
            name: "ExampleReview",
            dependencies: [
                .product(name: "LibraryDomain", package: "Library"),
                .product(name: "DictionaryDomain", package: "Dictionary"),
                .product(name: "DictionaryDI", package: "Dictionary"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
