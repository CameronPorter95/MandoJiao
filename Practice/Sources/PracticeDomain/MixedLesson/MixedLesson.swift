import Foundation
import LibraryDomain
import ProgressDomain

/// One step of a mixed lesson, as the exercise that runs it.
public nonisolated enum MixedStep: Hashable, Sendable {
    /// A word shown before it is asked. Nothing is answered.
    case teach(WordPair)
    /// One matching board.
    case match([WordPair])
    /// One flash card.
    case flashcard(Flashcard)
    /// One word's Hanzi read aloud.
    case readAloud(WordPair)

    /// Whether the step listens, so the microphone's session is wanted.
    public var listens: Bool {
        if case .readAloud = self { return true }
        return false
    }
}

/// Today's plan underway: the step showing, every answer so far, and the move to the next
/// step once one hands its answers back.
///
/// A value with no views, timers or sound. Each exercise runs its own step and reports what
/// was answered; this only keeps the order and the tallies, so its rules are tested alone.
public nonisolated struct MixedLesson: Equatable, Sendable {
    public let plan: TodayPlan
    public let steps: [MixedStep]
    public private(set) var stepIndex = 0
    public private(set) var isFinished = false
    /// Every answer, in the order given.
    public private(set) var answers: [Answer] = []

    /// A plan's steps made into exercises. A word to recognise is a flash card showing its
    /// Chinese with English to pick, one to produce shows its English for the Hanzi to be
    /// typed, each with wrong options from the rest of the vocabulary.
    public init(plan: TodayPlan, using random: inout some RandomNumberGenerator) {
        self.plan = plan
        steps = plan.steps.map { step in
            switch step {
            case .teach(let word):
                return .teach(word)
            case .match(let board):
                return .match(board)
            case .recall(let word, let recall):
                return .flashcard(FlashcardPlanBuilder.card(
                    for: word, showingChinese: recall == .recognise, picked: false,
                    choosingFrom: plan.otherWords, using: &random
                ))
            case .readAloud(let word):
                return .readAloud(word)
            }
        }
        isFinished = steps.isEmpty
    }

    public init(plan: TodayPlan) {
        var random = SystemRandomNumberGenerator()
        self.init(plan: plan, using: &random)
    }

    public var step: MixedStep? { isFinished ? nil : steps[stepIndex] }
    public var stepNumber: Int { min(stepIndex + 1, steps.count) }

    public var progress: Double {
        guard !steps.isEmpty else { return 1 }
        return isFinished ? 1 : Double(stepIndex) / Double(steps.count)
    }

    /// Records what the step showing answered and moves on, finishing after the last.
    public mutating func complete(with stepAnswers: [Answer]) {
        guard !isFinished else { return }
        answers += stepAnswers
        stepIndex += 1
        if stepIndex >= steps.count { isFinished = true }
    }

    /// Wrong answers, for the mistakes list, as the other lessons count them.
    public var missesByWordID: [UUID: Int] {
        answers.filter { !$0.isCorrect }.reduce(into: [:]) { $0[$1.wordID, default: 0] += 1 }
    }

    /// Answers right first time.
    public var cleanSolvesByWordID: [UUID: Int] {
        answers.filter { $0.isCorrect && $0.wrongAttempts == 0 }.reduce(into: [:]) { $0[$1.wordID, default: 0] += 1 }
    }

    /// Every word the lesson put to the learner, in the order first met.
    public var words: [WordPair] {
        var seen = Set<UUID>()
        return steps.flatMap { step -> [WordPair] in
            switch step {
            case .teach(let word), .readAloud(let word): [word]
            case .match(let board): board
            case .flashcard(let card): [card.word]
            }
        }
        .filter { seen.insert($0.id).inserted }
    }

    public var results: LessonResults {
        LessonResults(misses: missesByWordID, cleanSolves: cleanSolvesByWordID, answers: answers, source: plan.source)
    }
}
