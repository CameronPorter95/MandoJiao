import Foundation

/// What a lesson is drawn from. Kept as detached pairs so the lesson is stable
/// even if the library is edited while it is open.
public nonisolated struct LessonRequest: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let pool: [WordPair]
    /// The deck or folder the words came from, nil for words from across the vocabulary,
    /// as quick practice and the mistakes list draw them.
    public let source: LessonSource?

    public init(id: UUID = UUID(), title: String, pool: [WordPair], source: LessonSource? = nil) {
        self.id = id
        self.title = title
        self.pool = pool
        self.source = source
    }
}

/// A deck or folder practised, which home offers to carry on with.
public nonisolated enum LessonSource: Hashable, Sendable {
    case deck(UUID)
    case folder(UUID)
}
