import Foundation

/// What a finished lesson says about each word, keyed by word identity.
public nonisolated struct LessonResults: Equatable, Sendable {
    /// For the mistakes list.
    public var misses: [UUID: Int]
    public var cleanSolves: [UUID: Int]
    /// Every word put to the learner, in the order answered, kept whether right or wrong.
    public var answers: [Answer]

    public init(misses: [UUID: Int], cleanSolves: [UUID: Int], answers: [Answer] = []) {
        self.misses = misses
        self.cleanSolves = cleanSolves
        self.answers = answers
    }

    public var isEmpty: Bool { misses.isEmpty && cleanSolves.isEmpty && answers.isEmpty }
}

/// How one lesson changes one word's outstanding mistakes.
public nonisolated enum MistakeUpdate: Equatable, Sendable {
    case missed(missCount: Int)
    case earnedBack(missCount: Int)

    /// A word missed during the lesson has its mistakes recorded, and takes no credit
    /// for solving it later in that same lesson: getting it right after getting it
    /// wrong is not the same as knowing it.
    ///
    /// A word that came up clean, having been on the mistakes list already, works its
    /// way back off it. Nil means the lesson leaves the word as it was.
    public static func applying(_ results: LessonResults, to wordID: UUID, missCount: Int) -> MistakeUpdate? {
        if let missed = results.misses[wordID], missed > 0 {
            return .missed(missCount: missCount + missed)
        }
        if let solved = results.cleanSolves[wordID], solved > 0, missCount > 0 {
            return .earnedBack(missCount: max(0, missCount - solved))
        }
        return nil
    }
}
