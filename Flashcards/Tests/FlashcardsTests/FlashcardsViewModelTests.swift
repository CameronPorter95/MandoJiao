import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import FlashcardsDomain
@testable import FlashcardsUI
import VocabularyDomain

@Suite("Flash cards view model")
@MainActor
struct FlashcardsViewModelTests {
    private let repository = FakeVocabularyRepository()

    private let cards = [
        Flashcard(word: Words.water, direction: .englishToChinese, format: .typed),
        Flashcard(word: Words.tea, direction: .chineseToEnglish, format: .picked(options: [Words.book, Words.tea, Words.water, Words.dad])),
    ]

    private func makeViewModel(cards: [Flashcard]? = nil) -> (FlashcardsViewModel, EffectLog<FlashcardsEffect>) {
        let cards = cards ?? self.cards
        let viewModel = FlashcardsViewModel(
            request: LessonRequest(title: "t", pool: cards.map(\.word)),
            recordResults: RecordLessonResultsUseCase(repository: repository),
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
            recordResults: RecordLessonResultsUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        #expect(viewModel.state.lesson == nil)
        viewModel.send(.closeTapped)
        #expect(await log.contains(.close))
    }
}
