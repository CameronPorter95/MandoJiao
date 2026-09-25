import Foundation
import VocabularyDomain

/// A speaking lesson's progress, one card at a time.
///
/// A value with no timers, audio or microphone. `SpeakingViewModel` owns those and feeds
/// transcripts in through `submit`, so the three-attempt rule is exercised without audio
/// hardware. Typed answers go through the same door.
public struct SpeakingLesson: Equatable {
    public enum Phase: Equatable {
        case idle
        case wrong(heard: String, attemptsLeft: Int)
        case correct(heard: String)
        /// Out of attempts. The answer is shown and the card is recorded as a mistake.
        case exhausted(heard: String)

        public var isSettled: Bool {
            switch self {
            case .correct, .exhausted: return true
            case .idle, .wrong: return false
            }
        }
    }

    public let plan: SpeakingPlan
    public let strictness: AnswerStrictness

    public private(set) var cardIndex = 0
    public private(set) var phase: Phase = .idle
    public private(set) var attemptsUsed = 0
    public private(set) var isFinished = false

    /// Every failed attempt, not every failed card, so the accuracy figure lines up with
    /// how the matching lesson counts misses.
    public private(set) var failedAttempts = 0

    public private(set) var missesByPairID: [UUID: Int] = [:]
    public private(set) var cleanSolvesByPairID: [UUID: Int] = [:]

    /// Whether the card just left was solved.
    ///
    /// The speaking lesson keeps the microphone going into the next word after a correct answer,
    /// and stops after a wrong one so the answer can be read.
    public private(set) var advancedAfterCorrect = false

    public init(plan: SpeakingPlan, strictness: AnswerStrictness = .default) {
        self.plan = plan
        self.strictness = strictness
    }

    public var card: WordPair { plan.cards[min(cardIndex, max(plan.cards.count - 1, 0))] }

    public var cardNumber: Int { min(cardIndex + 1, plan.cardCount) }

    public var attemptsLeft: Int { max(0, SpeakingPlanBuilder.attemptsPerCard - attemptsUsed) }

    public var progress: Double {
        guard plan.cardCount > 0 else { return 0 }
        if isFinished { return 1 }
        let settled = phase.isSettled ? 1.0 : 0.0
        return (Double(cardIndex) + settled) / Double(plan.cardCount)
    }

    /// Words this speaking lesson failed outright, for the review screen.
    public var missedPairs: [(pair: WordPair, misses: Int)] {
        let byID = Dictionary(plan.cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return missesByPairID
            .compactMap { id, misses in byID[id].map { (pair: $0, misses: misses) } }
            .sorted { $0.pair.english < $1.pair.english }
    }

    public var clearedPairs: [WordPair] {
        let missed = Set(missesByPairID.keys)
        return plan.cards.filter { !missed.contains($0.id) && cleanSolvesByPairID[$0.id] != nil }
            .sorted { $0.english < $1.english }
    }

    /// Grades one attempt, whether it came from the microphone or the keyboard.
    ///
    /// Returns the verdict, or nil when the answer was ignored because the card had
    /// already settled or the speaking lesson had finished.
    ///
    /// Getting it right on the third go still counts as a clean solve. Three attempts
    /// exist because recognition of isolated words is unreliable, so spending them is not
    /// evidence that the word is unknown.
    @discardableResult
    public mutating func submit(_ response: String) -> Bool? {
        submit(SpeechOutcome(best: response))
    }

    @discardableResult
    public mutating func submit(_ outcome: SpeechOutcome) -> Bool? {
        guard !isFinished, !phase.isSettled else { return nil }

        attemptsUsed += 1
        let heard = outcome.best.trimmingCharacters(in: .whitespacesAndNewlines)
        let isRight = AnswerGrader.isCorrect(outcome, for: card, strictness: strictness)

        if isRight {
            cleanSolvesByPairID[card.id, default: 0] += 1
            phase = .correct(heard: heard)
        } else {
            failedAttempts += 1
            if attemptsLeft > 0 {
                phase = .wrong(heard: heard, attemptsLeft: attemptsLeft)
            } else {
                missesByPairID[card.id, default: 0] += 1
                phase = .exhausted(heard: heard)
            }
        }
        return isRight
    }

    /// Clears a failed verdict so a fresh attempt can show its own.
    ///
    /// Without this the previous failure stays on screen through the next attempt,
    /// sitting where the live transcript would be, so there is no way to see what the
    /// recogniser is making of the second or third try.
    ///
    /// A settled card is left alone: once a card is right or out of attempts, that
    /// verdict is the final word on it.
    public mutating func beginAttempt() {
        guard case .wrong = phase else { return }
        phase = .idle
    }

    /// Moves to the next card, or finishes after the last one.
    public mutating func advance() {
        guard !isFinished else { return }

        if case .correct = phase {
            advancedAfterCorrect = true
        } else {
            advancedAfterCorrect = false
        }
        attemptsUsed = 0
        phase = .idle

        let next = cardIndex + 1
        guard next < plan.cardCount else {
            isFinished = true
            return
        }
        cardIndex = next
    }
}
