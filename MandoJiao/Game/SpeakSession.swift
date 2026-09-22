import Foundation
import Observation

/// Drives a speech drill one card at a time.
///
/// It never touches the microphone. The view captures audio and hands the transcript to
/// `submit`, which means the whole exercise, including the three-attempt rule, can be
/// exercised without audio hardware. Typed answers go through the same door.
@MainActor
@Observable
final class SpeakSession {
    enum Phase: Equatable {
        case idle
        case wrong(heard: String, attemptsLeft: Int)
        case correct(heard: String)
        /// Out of attempts. The answer is shown and the card is recorded as a mistake.
        case exhausted(heard: String)

        var isSettled: Bool {
            switch self {
            case .correct, .exhausted: return true
            case .idle, .wrong: return false
            }
        }
    }

    let plan: SpeakPlan

    private(set) var cardIndex = 0
    private(set) var phase: Phase = .idle
    private(set) var attemptsUsed = 0
    private(set) var isFinished = false

    /// Every failed attempt, not every failed card, so the accuracy figure lines up with
    /// how the matching lesson counts misses.
    private(set) var failedAttempts = 0

    private(set) var missesByPairID: [UUID: Int] = [:]
    private(set) var cleanSolvesByPairID: [UUID: Int] = [:]

    private(set) var feedbackToken = 0

    private let sounds: MatchSoundPlaying
    private let strictness: MatchStrictness
    private var isAdvancing = false
    private var advanceTask: Task<Void, Never>?
    private let advanceDelay: Duration = .milliseconds(850)

    init(
        plan: SpeakPlan,
        strictness: MatchStrictness = .default,
        sounds: MatchSoundPlaying? = nil
    ) {
        self.plan = plan
        self.strictness = strictness
        self.sounds = sounds ?? MatchSounds.shared
    }

    var card: WordPair { plan.cards[min(cardIndex, max(plan.cards.count - 1, 0))] }

    var cardNumber: Int { min(cardIndex + 1, plan.cardCount) }

    var attemptsLeft: Int { max(0, SpeakLessonBuilder.attemptsPerCard - attemptsUsed) }

    var progress: Double {
        guard plan.cardCount > 0 else { return 0 }
        if isFinished { return 1 }
        let settled = phase.isSettled ? 1.0 : 0.0
        return (Double(cardIndex) + settled) / Double(plan.cardCount)
    }

    /// Words this drill failed outright, for the review screen.
    var missedPairs: [(pair: WordPair, misses: Int)] {
        let byID = Dictionary(plan.cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return missesByPairID
            .compactMap { id, misses in byID[id].map { (pair: $0, misses: misses) } }
            .sorted { $0.pair.english < $1.pair.english }
    }

    var clearedPairs: [WordPair] {
        let missed = Set(missesByPairID.keys)
        return plan.cards.filter { !missed.contains($0.id) && cleanSolvesByPairID[$0.id] != nil }
            .sorted { $0.english < $1.english }
    }

    /// Grades one attempt, whether it came from the microphone or the keyboard.
    ///
    /// Getting it right on the third go still counts as a clean solve. Three attempts
    /// exist because recognition of isolated words is unreliable, so spending them is not
    /// evidence that the word is unknown.
    func submit(_ response: String) {
        submit(SpeechOutcome(best: response))
    }

    func submit(_ outcome: SpeechOutcome) {
        guard !isFinished, !isAdvancing, !phase.isSettled else { return }

        attemptsUsed += 1
        let heard = outcome.best.trimmingCharacters(in: .whitespacesAndNewlines)

        if AnswerGrader.isCorrect(outcome, for: card, strictness: strictness) {
            cleanSolvesByPairID[card.id, default: 0] += 1
            phase = .correct(heard: heard)
            sounds.playMatch(step: cardIndex, of: plan.cardCount)
            scheduleAdvance()
        } else {
            failedAttempts += 1
            if attemptsLeft > 0 {
                phase = .wrong(heard: heard, attemptsLeft: attemptsLeft)
            } else {
                missesByPairID[card.id, default: 0] += 1
                phase = .exhausted(heard: heard)
            }
            sounds.playMiss()
        }

        feedbackToken += 1
    }

    /// Used by the "continue" button after a card runs out of attempts. A correct card
    /// advances itself.
    func advance() {
        // Cancels any pending auto-advance, so advancing by hand cannot land twice.
        advanceTask?.cancel()
        advanceTask = nil
        isAdvancing = false
        attemptsUsed = 0
        phase = .idle

        let next = cardIndex + 1
        guard next < plan.cardCount else {
            isFinished = true
            sounds.playLessonComplete()
            return
        }
        cardIndex = next
    }

    private func scheduleAdvance() {
        isAdvancing = true
        advanceTask = Task { [advanceDelay] in
            try? await Task.sleep(for: advanceDelay)
            guard !Task.isCancelled else { return }
            self.advance()
        }
    }
}
