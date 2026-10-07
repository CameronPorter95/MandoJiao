import Foundation
import VocabularyDomain

/// A flash card lesson's progress: the card showing, one try at it, then the answer.
///
/// A value with no timers or sound, so its rules are tested on their own, as the matching
/// and speaking lessons' are.
public nonisolated struct FlashcardLesson: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case answering
        /// `given` is what was typed, or the option picked as it showed, and empty when the
        /// learner said they did not know.
        case answered(isCorrect: Bool, given: String)
    }

    public let plan: FlashcardPlan
    public private(set) var cardIndex = 0
    public private(set) var phase: Phase = .answering
    public private(set) var isFinished = false

    /// For the mistakes list, in the shape the other lessons give it.
    public private(set) var missesByPairID: [UUID: Int] = [:]
    public private(set) var cleanSolvesByPairID: [UUID: Int] = [:]
    /// One per card answered. A card closed on before it was answered is not counted.
    public private(set) var answers: [Answer] = []

    public init(plan: FlashcardPlan) {
        self.plan = plan
    }

    public var card: Flashcard { plan.cards[min(cardIndex, max(plan.cards.count - 1, 0))] }
    public var cardNumber: Int { min(cardIndex + 1, plan.cardCount) }

    public var progress: Double {
        guard plan.cardCount > 0 else { return 0 }
        if isFinished { return 1 }
        let answered = phase == .answering ? 0.0 : 1.0
        return (Double(cardIndex) + answered) / Double(plan.cardCount)
    }

    public var wrongCount: Int { missesByPairID.values.reduce(0, +) }

    public var missedPairs: [(pair: WordPair, misses: Int)] {
        plan.cards.compactMap { card in missesByPairID[card.word.id].map { (pair: card.word, misses: $0) } }
    }

    public var clearedPairs: [WordPair] {
        plan.cards.map(\.word).filter { cleanSolvesByPairID[$0.id] != nil && missesByPairID[$0.id] == nil }
    }

    /// The verdict, or nil when the text cannot be checked, as `FlashcardGrader.canCheck`
    /// says, or the card is not a typed one waiting for its answer. Nil spends no try.
    @discardableResult
    public mutating func submit(typed text: String) -> Bool? {
        guard !isFinished, phase == .answering, card.format == .typed,
              FlashcardGrader.canCheck(text, for: card)
        else { return nil }
        let isRight = FlashcardGrader.isCorrect(text, for: card)
        settle(isRight, given: text.trimmingCharacters(in: .whitespacesAndNewlines))
        return isRight
    }

    /// The verdict, or nil when the card is not picked from options or is already answered.
    @discardableResult
    public mutating func pick(_ option: WordPair) -> Bool? {
        guard !isFinished, phase == .answering, case .picked(let options) = card.format,
              options.contains(option)
        else { return nil }
        let isRight = option.id == card.word.id
        settle(isRight, given: card.showsChinese ? option.english : option.hanzi)
        return isRight
    }

    /// Gives the card up: the answer shows and it counts as a mistake, recorded as wrong
    /// with no tries, which tells giving up apart from guessing wrong. Nil when the card
    /// is already answered.
    @discardableResult
    public mutating func skip() -> Bool? {
        guard !isFinished, phase == .answering else { return nil }
        settle(false, given: "", tries: 0)
        return false
    }

    /// Moves to the next card, or finishes after the last. Only once the card is answered.
    public mutating func advance() {
        guard !isFinished, phase != .answering else { return }
        phase = .answering
        let next = cardIndex + 1
        guard next < plan.cardCount else {
            isFinished = true
            return
        }
        cardIndex = next
    }

    private mutating func settle(_ isRight: Bool, given: String, tries: Int = 1) {
        let id = card.word.id
        if isRight {
            cleanSolvesByPairID[id, default: 0] += 1
        } else {
            missesByPairID[id, default: 0] += 1
        }
        answers.append(Answer(
            wordID: id, exercise: card.exercise, direction: card.direction,
            isCorrect: isRight, wrongAttempts: isRight ? 0 : tries
        ))
        phase = .answered(isCorrect: isRight, given: given)
    }
}
