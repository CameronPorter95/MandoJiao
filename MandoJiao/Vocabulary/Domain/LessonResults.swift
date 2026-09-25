import Foundation

/// What a finished lesson says about each word, keyed by word identity.
nonisolated struct LessonResults: Equatable, Sendable {
    var misses: [UUID: Int]
    var cleanSolves: [UUID: Int]

    var isEmpty: Bool { misses.isEmpty && cleanSolves.isEmpty }
}

/// How one lesson changes one word's outstanding mistakes.
nonisolated enum MistakeUpdate: Equatable, Sendable {
    case missed(missCount: Int)
    case earnedBack(missCount: Int)

    /// A word missed during the lesson has its mistakes recorded, and takes no credit
    /// for solving it later in that same lesson: getting it right after getting it
    /// wrong is not the same as knowing it.
    ///
    /// A word that came up clean, having been on the mistakes list already, works its
    /// way back off it. Nil means the lesson leaves the word as it was.
    static func applying(_ results: LessonResults, to wordID: UUID, missCount: Int) -> MistakeUpdate? {
        if let missed = results.misses[wordID], missed > 0 {
            return .missed(missCount: missCount + missed)
        }
        if let solved = results.cleanSolves[wordID], solved > 0, missCount > 0 {
            return .earnedBack(missCount: max(0, missCount - solved))
        }
        return nil
    }
}
