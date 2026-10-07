import Foundation
import Testing
@testable import VocabularyDomain

/// The memory model's behaviour, pinned on answer patterns a learner makes. Its constants
/// are judged, not fitted, so a change to one shows here as a moved band.
@Suite("Word memory")
nonisolated struct WordMemoryTests {
    private let start = Date(timeIntervalSince1970: 0)

    private func day(_ days: Double) -> Date { start.addingTimeInterval(days * 86_400) }

    private func answer(_ exercise: Answer.Exercise, right: Bool = true, wrong: Int = 0) -> Answer {
        Answer(wordID: UUID(), exercise: exercise, direction: nil, isCorrect: right, wrongAttempts: wrong)
    }

    private func replay(_ steps: [(Double, Answer)]) -> WordMemory {
        steps.reduce(WordMemory.new) { $0.answered($1.1, at: day($1.0)) }
    }

    @Test("a word never answered is new, and nothing recalls it")
    func new() {
        #expect(WordMemory.new.band(at: day(0)) == .new)
        #expect(WordMemory.new.recall(at: day(0)) == 0)
    }

    @Test("typing it right on spaced days takes it from learning to familiar to known")
    func spacedTyping() {
        let typed = answer(.flashcardTyped)
        #expect(replay([(0, typed)]).band(at: day(0)) == .learning)
        #expect(replay([(0, typed), (1, typed)]).band(at: day(1)) == .learning)
        #expect(replay([(0, typed), (1, typed), (4, typed)]).band(at: day(4)) == .familiar)
        #expect(replay([(0, typed), (1, typed), (4, typed), (12, typed)]).band(at: day(12)) == .known)
    }

    @Test("answering it again the same day adds almost nothing, so one long lesson is not a month of practice")
    func sameDay() {
        let once = replay([(0, answer(.flashcardTyped))])
        let five = replay((0..<5).map { _ in (0, answer(.flashcardTyped)) })
        #expect(abs(five.stability - once.stability) < 0.01)
    }

    @Test("recognising it counts for less than recalling it, and matching alone never makes it known")
    func recognitionCountsLess() {
        let days: [Double] = [0, 1, 4, 12]
        let typed = replay(days.map { ($0, answer(.flashcardTyped)) })
        let picked = replay(days.map { ($0, answer(.flashcardPicked)) })
        let matched = replay(days.map { ($0, answer(.matching)) })
        #expect(typed.stability > picked.stability)
        #expect(picked.stability > matched.stability)
        let daily = replay((0..<30).map { (Double($0), answer(.matching)) })
        #expect(daily.band(at: day(29)) != .known)
    }

    @Test("right on speaking's third try counts as right first time, since the recogniser mishears single words")
    func speakingTries() {
        let first = replay([(0, answer(.speaking))])
        let third = replay([(0, answer(.speaking, wrong: 2))])
        #expect(first == third)
        let typedLate = replay([(0, answer(.flashcardTyped, wrong: 1))])
        #expect(typedLate.stability < replay([(0, answer(.flashcardTyped))]).stability)
    }

    @Test("a wrong answer knocks a known word back, a wrong matching pair less, since it implicates both words")
    func lapses() {
        let known = replay([(0, answer(.flashcardTyped)), (3, answer(.flashcardTyped)), (10, answer(.flashcardTyped))])
        #expect(known.band(at: day(10)) == .known)
        let typedWrong = known.answered(answer(.flashcardTyped, right: false, wrong: 1), at: day(30))
        let matchedWrong = known.answered(answer(.matching, right: false, wrong: 1), at: day(30))
        #expect(typedWrong.band(at: day(30)) == .learning)
        #expect(matchedWrong.band(at: day(30)) == .familiar)
        #expect(typedWrong.stability < matchedWrong.stability)
    }

    @Test("a word left too long slips back a band")
    func fading() {
        let familiar = replay([(0, answer(.flashcardTyped)), (1, answer(.flashcardTyped)), (4, answer(.flashcardTyped))])
        #expect(familiar.band(at: day(4)) == .familiar)
        #expect(familiar.band(at: day(60)) == .learning)
    }

    @Test("marking it learnt makes it known at once, it fades from there, and unmarking keeps its strength")
    func learnt() {
        let learnt = WordMemory.new.markedLearnt(at: day(0))
        #expect(learnt.isLearnt)
        #expect(learnt.band(at: day(0)) == .known)
        #expect(learnt.band(at: day(120)) != .known)
        let unmarked = learnt.unmarkedLearnt()
        #expect(!unmarked.isLearnt)
        #expect(unmarked.stability == learnt.stability)
        // Answers keep the mark.
        #expect(learnt.answered(answer(.flashcardTyped), at: day(1)).isLearnt)
    }
}
