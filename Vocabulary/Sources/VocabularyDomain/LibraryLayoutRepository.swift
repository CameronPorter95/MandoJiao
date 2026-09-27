import Foundation

/// Synchronous, because the layout is a local value read once when the library opens.
public nonisolated protocol LibraryLayoutRepository: Sendable {
    func layout() -> LibraryLayout
    func save(_ layout: LibraryLayout)
}
