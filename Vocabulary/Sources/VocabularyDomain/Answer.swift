import Foundation

/// One word put to the learner once, and how it went: the record a word's strength will be
/// worked out from. Kept for every exercise, so a later one adds evidence rather than
/// replacing it.
public nonisolated struct Answer: Hashable, Sendable {
    /// Stored by raw value: rename a case only by keeping its raw value.
    public enum Exercise: String, Hashable, Sendable, CaseIterable {
        case matching
        case speaking
    }

    /// What was shown, and what was asked for. Stored by raw value.
    public enum Direction: String, Hashable, Sendable, CaseIterable {
        /// The English shown, the Chinese asked for, as a speaking card does.
        case englishToChinese
        case chineseToEnglish
    }

    public let wordID: UUID
    public let exercise: Exercise
    /// Nil where both sides show at once, as on a matching board.
    public let direction: Direction?
    /// Whether it ended right, however many tries that took.
    public let isCorrect: Bool
    /// Wrong tries before it came right, or before the tries ran out.
    public let wrongAttempts: Int

    public init(wordID: UUID, exercise: Exercise, direction: Direction?, isCorrect: Bool, wrongAttempts: Int) {
        self.wordID = wordID
        self.exercise = exercise
        self.direction = direction
        self.isCorrect = isCorrect
        self.wrongAttempts = wrongAttempts
    }
}
