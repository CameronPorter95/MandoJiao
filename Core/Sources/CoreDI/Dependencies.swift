import SwiftData

/// The dependency-injection primitive. Concrete registrations are composition and live
/// in the app target (`LiveDependencies`), so `CoreDI` never gains an edge to a feature.
@MainActor
public protocol Dependencies {
    /// The one store for the app's lifetime.
    var modelContainer: ModelContainer { get }
}
