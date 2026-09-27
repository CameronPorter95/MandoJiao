// swift-tools-version: 6.2
import PackageDescription

/// Views and view models are main-actor by nature; domain and data are not.
let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Core",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "CorePersistence", targets: ["CorePersistence"]),
        .library(name: "CoreDesignSystem", targets: ["CoreDesignSystem"]),
        .library(name: "CoreUI", targets: ["CoreUI"]),
        .library(name: "CoreSound", targets: ["CoreSound"]),
        .library(name: "CoreDI", targets: ["CoreDI"]),
        .library(name: "CoreTestSupport", targets: ["CoreTestSupport"]),
    ],
    targets: [
        .target(name: "CoreDomain"),
        .target(name: "CorePersistence", dependencies: ["CoreDomain"]),
        .target(name: "CoreDesignSystem", swiftSettings: mainActorByDefault),
        .target(name: "CoreUI", dependencies: ["CoreDomain", "CoreDesignSystem"], swiftSettings: mainActorByDefault),
        .target(name: "CoreSound", dependencies: ["CoreDomain"], swiftSettings: mainActorByDefault),
        // DI primitives only, never registrations.
        .target(name: "CoreDI", swiftSettings: mainActorByDefault),
        .target(name: "CoreTestSupport", path: "TestSupport", swiftSettings: mainActorByDefault),
        .testTarget(
            name: "CoreTests",
            dependencies: ["CoreUI", "CoreSound", "CoreTestSupport"],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
