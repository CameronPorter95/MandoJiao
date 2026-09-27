import CoreDI
import SwiftData

/// The production `Dependencies` graph. Composition rather than a DI primitive, so it
/// belongs at the composition root rather than in `CoreDI`.
struct LiveDependencies: Dependencies {
    let modelContainer: ModelContainer
}
