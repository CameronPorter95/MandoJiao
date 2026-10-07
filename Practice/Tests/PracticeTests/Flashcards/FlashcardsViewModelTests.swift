import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import PracticeDomain
@testable import PracticeUI
import VocabularyDomain

@Suite("Flash cards view model")
@MainActor
struct FlashcardsViewModelTests {
    private let repository = FakeVocabularyRepository()
    private let sounds = FakeSounds()

    private let cards = [
        Flashcard(word: Words.water, direction: .englishToChinese, format: .typed),
        Flashcard(word: Words.tea, direction: .chineseToEnglish, format: .picked(options: [Words.book, Words.tea, Words.water, Words.dad])),
    ]

    private func makeViewModel(cards: [Flashcard]? = nil) -> (FlashcardsViewModel, EffectLog<FlashcardsEffect>) {
        let cards = cards ?? self.cards
        let viewModel = FlashcardsViewModel(
            request: LessonRequest(title: "t", pool: cards.map(\.word), source: .deck(testDeckID)),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            sounds: sounds,
            makePlan: { FlashcardPlan(title: $0.title, cards: cards) }
        )
        viewModel.send(.appeared)
        return (viewModel, EffectLog(viewModel.effects()))
    }

    @Test("a verdict buzzes, and an answer the card cannot take gets none and spends no try")
    func verdicts() async {
        let (viewModel, log) = makeViewModel()
        viewModel.send(.typedAnswerSubmitted("shui"))
        #expect(viewModel.state.lesson?.phase == .answering)

        viewModel.send(.typedAnswerSubmitted("水"))
        #expect(await log.contains(.haptic(.success)))
        viewModel.send(.continueTapped)
        viewModel.send(.optionPicked(Words.book.id))
        #expect(await log.contains(.haptic(.error)))
        #expect(log.effects.filter { if case .haptic = $0 { true } else { false } }.count == 2)
    }

    @Test("a right answer plays the success tone on the same note each time, and a wrong one plays nothing")
    func successTone() {
        let (viewModel, _) = makeViewModel()
        #expect(sounds.played == ["prepare"])
        viewModel.send(.typedAnswerSubmitted("水"))
        #expect(sounds.played == ["prepare", "match 0 of 1"])
        viewModel.send(.continueTapped)
        viewModel.send(.optionPicked(Words.book.id))
        #expect(sounds.played == ["prepare", "match 0 of 1"])
    }

    @Test("leaving the last card plays the lesson complete tune, once")
    func completeTune() {
        let (viewModel, _) = makeViewModel()
        viewModel.send(.typedAnswerSubmitted("水"))
        viewModel.send(.continueTapped)
        #expect(!sounds.played.contains("complete"))
        viewModel.send(.optionPicked(Words.tea.id))
        viewModel.send(.continueTapped)
        viewModel.send(.continueTapped)
        #expect(sounds.played == ["prepare", "match 0 of 1", "match 0 of 1", "complete"])
    }

    @Test("don't know shows the answer and counts as a mistake, with no tone or buzz")
    func dontKnow() async {
        let (viewModel, log) = makeViewModel()
        viewModel.send(.dontKnowTapped)
        #expect(viewModel.state.lesson?.phase == .answered(isCorrect: false, given: ""))
        viewModel.send(.continueTapped)
        viewModel.send(.dontKnowTapped)
        viewModel.send(.continueTapped)

        #expect(await waitUntil { await repository.recordedResults.count == 1 })
        let results = await repository.recordedResults.first
        #expect(results?.misses == [Words.water.id: 1, Words.tea.id: 1])
        #expect(results?.answers.map(\.wrongAttempts) == [0, 0])
        #expect(results?.answers.map(\.isCorrect) == [false, false])
        #expect(sounds.played == ["prepare", "complete"])
        #expect(!log.effects.contains { if case .haptic = $0 { true } else { false } })
    }

    @Test("the last card left records every answer, with the tallies the mistakes list uses")
    func recordsAtTheEnd() async {
        let (viewModel, _) = makeViewModel()
        viewModel.send(.typedAnswerSubmitted("水"))
        viewModel.send(.continueTapped)
        viewModel.send(.optionPicked(Words.book.id))
        viewModel.send(.continueTapped)

        #expect(viewModel.state.lesson?.isFinished == true)
        #expect(await waitUntil { await repository.recordedResults.count == 1 })
        let results = await repository.recordedResults.first
        #expect(results?.cleanSolves == [Words.water.id: 1])
        #expect(results?.misses == [Words.tea.id: 1])
        #expect(results?.answers.map(\.exercise) == [.flashcardTyped, .flashcardPicked])
        #expect(results?.answers.map(\.direction) == [.englishToChinese, .chineseToEnglish])
        // So the deck is marked practised, for home to carry on with.
        #expect(results?.source == .deck(testDeckID))
    }

    @Test("closing part way asks first, then records what was answered once")
    func closingEarly() async {
        let (viewModel, log) = makeViewModel()
        viewModel.send(.closeTapped)
        #expect(await log.contains(.close))

        let (started, startedLog) = makeViewModel()
        started.send(.typedAnswerSubmitted("水"))
        started.send(.closeTapped)
        #expect(started.state.isConfirmingQuit)
        started.send(.quitConfirmed)
        #expect(await startedLog.contains(.close))
        #expect(await waitUntil { await repository.recordedResults.count == 1 })
        #expect(await repository.recordedResults.first?.answers.count == 1)
    }

    @Test("a failed save says why")
    func failedSave() async {
        await repository.failWrites()
        let (viewModel, log) = makeViewModel(cards: [cards[0]])
        viewModel.send(.typedAnswerSubmitted("水"))
        viewModel.send(.continueTapped)
        #expect(await log.contains(.showError(.recordResultsFailed(FakeVocabularyRepository.failure))))
    }

    @Test("a request with no usable words has no lesson and closes without asking")
    func noWords() async {
        let viewModel = FlashcardsViewModel(
            request: LessonRequest(title: "t", pool: [WordPair(english: "", hanzi: "空")]),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            sounds: sounds
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        #expect(viewModel.state.lesson == nil)
        viewModel.send(.closeTapped)
        #expect(await log.contains(.close))
    }
}

@MainActor
private final class FakeSounds: MatchSoundPlaying {
    private(set) var played: [String] = []
    func prepare() { played.append("prepare") }
    func playMatch(step: Int, of total: Int) { played.append("match \(step) of \(total)") }
    func playMiss() { played.append("miss") }
    func playLessonComplete() { played.append("complete") }
}

private let testDeckID = UUID()
