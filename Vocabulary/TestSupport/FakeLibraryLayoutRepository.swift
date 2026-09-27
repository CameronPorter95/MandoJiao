import Foundation
import VocabularyDomain

/// Keeps the layout in memory, and records every save.
public final class FakeLibraryLayoutRepository: LibraryLayoutRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: LibraryLayout
    public private(set) var saves = 0

    public init(_ layout: LibraryLayout = LibraryLayout()) {
        stored = layout
    }

    public func layout() -> LibraryLayout {
        lock.withLock { stored }
    }

    public func save(_ layout: LibraryLayout) {
        lock.withLock {
            stored = layout
            saves += 1
        }
    }
}
