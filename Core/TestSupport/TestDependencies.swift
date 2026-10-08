import CoreDI
import SwiftData

/// An empty in-memory store, for factories whose screens never touch it.
public struct TestDependencies: Dependencies {
    public let modelContainer: ModelContainer

    public init() throws {
        modelContainer = try ModelContainer(for: Schema([]), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
