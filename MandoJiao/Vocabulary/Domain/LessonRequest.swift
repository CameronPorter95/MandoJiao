import Foundation

/// What a lesson is drawn from. Kept as detached pairs so the lesson is stable
/// even if the library is edited while it is open.
nonisolated struct LessonRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let pool: [WordPair]

    init(id: UUID = UUID(), title: String, pool: [WordPair]) {
        self.id = id
        self.title = title
        self.pool = pool
    }
}
