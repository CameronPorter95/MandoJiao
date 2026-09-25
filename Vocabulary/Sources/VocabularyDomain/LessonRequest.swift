import Foundation

/// What a lesson is drawn from. Kept as detached pairs so the lesson is stable
/// even if the library is edited while it is open.
public nonisolated struct LessonRequest: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let pool: [WordPair]

    public init(id: UUID = UUID(), title: String, pool: [WordPair]) {
        self.id = id
        self.title = title
        self.pool = pool
    }
}
