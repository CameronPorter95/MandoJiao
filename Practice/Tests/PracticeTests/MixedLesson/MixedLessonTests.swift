import ProgressDomain
import CoreDomain
import CoreTestSupport
import Foundation
import Testing
import LibraryTestSupport
@testable import PracticeDomain
@testable import PracticeUI
import LibraryDomain

nonisolated enum LessonWords {
    static let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    static let tea = WordPair(english: "tea", hanzi: "茶", pinyin: "chá")
    static let book = WordPair(english: "book", hanzi: "书", pinyin: "shū")
    static let car = WordPair(english: "car", hanzi: "车", pinyin: "chē")
    static let big = WordPair(english: "big", hanzi: "大", pinyin: "dà")
    static let all = [water, tea, book, car, big]
}

nonisolated private let deckID = UUID()

nonisolated private func plan(_ steps: [TodayPlan.Step]) -> TodayPlan {
    TodayPlan(theme: .newWords, title: "New words", synopsis: "Learn.", steps: steps, source: .deck(deckID), otherWords: LessonWords.all)
}

nonisolated private func answer(_ word: WordPair, right: Bool, exercise: Answer.Exercise = .flashcardPicked) -> Answer {
    Answer(wordID: word.id, exercise: exercise, direction: nil, isCorrect: right, wrongAttempts: right ? 0 : 1)
}

@Suite("Mixed lesson")
nonisolated struct MixedLessonDomainTests {
    @Test("a plan's steps become exercises: a word to recognise shows Chinese to pick, one to produce shows English to type")
    func steps() {
        let lesson = MixedLesson(plan: plan([
            .teach(LessonWords.water), .match(LessonWords.all), .recall(LessonWords.water, .recognise), .recall(LessonWords.tea, .produce),
        ]))
        #expect(lesson.steps[0] == .teach(LessonWords.water))
        #expect(lesson.steps[1] == .match(LessonWords.all))
        guard case .flashcard(let recognise) = lesson.steps[2], case .flashcard(let produce) = lesson.steps[3] else {
            Issue.record("expected flash cards")
            return
        }
        #expect(recognise.direction == .chineseToEnglish)
        #expect(recognise.format != .typed)
        #expect(produce.direction == .englishToChinese)
        #expect(produce.format == .typed)
    }

    @Test("each step's answers are kept, and the results carry the plan's deck for the mistakes list and strengths")
    func answers() {
        var lesson = MixedLesson(plan: plan([.teach(LessonWords.water), .recall(LessonWords.water, .recognise), .recall(LessonWords.tea, .recognise)]))
        lesson.complete(with: [])
        #expect(lesson.stepIndex == 1)
        lesson.complete(with: [answer(LessonWords.water, right: true)])
        lesson.complete(with: [answer(LessonWords.tea, right: false)])
        #expect(lesson.isFinished)
        #expect(lesson.progress == 1)
        let results = lesson.results
        #expect(results.cleanSolves == [LessonWords.water.id: 1])
        #expect(results.misses == [LessonWords.tea.id: 1])
        #expect(results.answers.count == 2)
        #expect(results.source == .deck(deckID))
        // Taught words, though nothing was answered for them, are words of the lesson.
        #expect(lesson.words == [LessonWords.water, LessonWords.tea])
        lesson.complete(with: [answer(LessonWords.book, right: true)])
        #expect(lesson.answers.count == 2)
    }

    @Test("a word to read aloud is a step that listens, and the only kind that does")
    func readAloud() {
        let lesson = MixedLesson(plan: plan([.teach(LessonWords.water), .recall(LessonWords.water, .recognise), .readAloud(LessonWords.tea)]))
        #expect(lesson.steps[2] == .readAloud(LessonWords.tea))
        #expect(lesson.steps.map(\.listens) == [false, false, true])
        #expect(lesson.words == [LessonWords.water, LessonWords.tea])
    }
}

@Suite("Mixed lesson view model")
@MainActor
struct MixedLessonViewModelTests {
    private let repository = FakeVocabularyRepository()
    private let sounds = FakeSounds()

    private func makeViewModel(
        _ steps: [TodayPlan.Step] = [.teach(LessonWords.water), .recall(LessonWords.water, .recognise)]
    ) -> (MixedLessonViewModel, EffectLog<MixedLessonEffect>) {
        let viewModel = MixedLessonViewModel(
            lesson: MixedLesson(plan: plan(steps)),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            sounds: sounds,
            audioSession: sounds
        )
        return (viewModel, EffectLog(viewModel.effects()))
    }

    @Test("the last step plays the finishing tune and records the lesson once, with its deck")
    func finishing() async {
        let (viewModel, _) = makeViewModel()
        viewModel.send(.stepCompleted([]))
        #expect(sounds.played.isEmpty)
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true)]))
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true)]))
        #expect(await waitUntil { sounds.played.contains("complete") })
        #expect(await waitUntil { await repository.recordedResults.count == 1 })
        #expect(await repository.recordedResults.first?.source == .deck(deckID))
        viewModel.send(.closeTapped)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await repository.recordedResults.count == 1)
    }

    @Test("closing part way asks first, then records what was answered")
    func quitting() async {
        let (viewModel, log) = makeViewModel()
        viewModel.send(.stepCompleted([]))
        viewModel.send(.closeTapped)
        #expect(viewModel.state.isConfirmingQuit)
        viewModel.send(.quitConfirmed)
        #expect(await log.contains(.close))
        // Nothing answered yet, so nothing to record.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await repository.recordedResults.isEmpty)
    }

    @Test("the microphone's session is kept through a run of read-aloud steps, handed back before anything else, and before the fanfare")
    func audioSession() async {
        let (viewModel, _) = makeViewModel([
            .readAloud(LessonWords.water), .readAloud(LessonWords.tea), .recall(LessonWords.water, .recognise), .readAloud(LessonWords.book),
        ])
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true, exercise: .speaking)]))
        await settle()
        #expect(sounds.played.isEmpty)

        viewModel.send(.stepCompleted([answer(LessonWords.tea, right: true, exercise: .speaking)]))
        #expect(await waitUntil { sounds.played == ["exit"] })

        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true)]))
        viewModel.send(.stepCompleted([answer(LessonWords.book, right: true, exercise: .speaking)]))
        #expect(await waitUntil { sounds.played == ["exit", "exit", "complete"] })
    }

    @Test("closing, or the lesson going away, hands the microphone's session back")
    func audioSessionOnLeaving() async {
        let (viewModel, log) = makeViewModel([.readAloud(LessonWords.water), .readAloud(LessonWords.tea)])
        viewModel.send(.closeTapped)
        #expect(await log.contains(.close))
        #expect(await waitUntil { sounds.played == ["exit"] })
        viewModel.send(.disappeared)
        #expect(await waitUntil { sounds.played == ["exit", "exit"] })
    }

    @Test("a failed save says why")
    func failedSave() async {
        await repository.failWrites()
        let (viewModel, log) = makeViewModel()
        viewModel.send(.stepCompleted([]))
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: false)]))
        #expect(await log.contains(.showError(.recordResultsFailed(FakeVocabularyRepository.failure))))
    }
}

/// Sounds and the audio session in one log, so their order shows.
@MainActor
private final class FakeSounds: MatchSoundPlaying, AudioSessionSwitching {
    private(set) var played: [String] = []
    func enterRecordingMode() { played.append("enter") }
    func exitRecordingMode() async { played.append("exit") }
    func prepare() {}
    func playMatch(step: Int, of total: Int) { played.append("match") }
    func playMiss() { played.append("miss") }
    func playLessonComplete() { played.append("complete") }
}
