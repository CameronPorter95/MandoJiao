import Foundation
import LibraryDomain

/// One graded answer, as the attempt log records it.
public struct SpeechAttempt: Sendable {
    public let card: WordPair
    public let outcome: SpeechOutcome
    public let strictness: AnswerStrictness
    public let attempt: Int
    public let totalAttempts: Int
    public let wasCorrect: Bool

    public init(card: WordPair, outcome: SpeechOutcome, strictness: AnswerStrictness, attempt: Int, totalAttempts: Int, wasCorrect: Bool) {
        self.card = card
        self.outcome = outcome
        self.strictness = strictness
        self.attempt = attempt
        self.totalAttempts = totalAttempts
        self.wasCorrect = wasCorrect
    }
}
