import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

@Suite("Home")
@MainActor
struct HomeViewModelTests {
    private let lessonSettings = FakeLessonSettings()
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)
    private let rounds = Box(10)

    private func makeHome() async -> (HomeViewModel, EffectLog<HomeEffect>) {
        let viewModel = HomeViewModel(
            minimumMatchingWords: 5,
            quickPracticeRounds: { rounds.value },
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: GetLessonSettingsUseCase(repository: lessonSettings),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.vocabulary == Fixtures.vocabulary }
        return (viewModel, log)
    }

    @Test("appearing shows the library")
    func loading() async {
        let (home, _) = await makeHome()
        #expect(home.state.usableWordCount == 5)
        #expect(home.state.canStartQuickPractice)
        #expect(home.state.mistakeWords.map(\.english) == ["mobile phone", "book", "tea"])
    }

    @Test("with nothing practised there is nothing to carry on with, only the folders and decks to choose from")
    func nothingPractised() async {
        let (home, _) = await makeHome()
        #expect(home.state.current == nil)
        #expect(home.state.sourceSections.map(\.title) == ["Starter"])
        #expect(home.state.sourceSections.first?.decks.map(\.deck.name) == ["Full", "Small"])
        #expect(home.state.sourceSections.first?.wordCount == 5)
    }

    @Test("the deck or folder last practised is what to carry on with, and a lesson from it says where it came from")
    func carryingOn() async {
        let (home, log) = await makeHome()
        try? await repository.recordResults(LessonResults(misses: [:], cleanSolves: [Fixtures.water.id: 1], source: .deck(Fixtures.fullDeck.id)))
        #expect(await waitUntil { home.state.current == .deck(Fixtures.fullDeck.id) })
        #expect(home.state.currentName == "Full")
        #expect(home.state.currentSubtitle == "Starter · 5 words")

        home.send(.continueTapped(.flashcards))
        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestFlashcards(let request) = log.effects.first else {
            Issue.record("expected a flash card request")
            return
        }
        #expect(request.title == "Full")
        #expect(request.pool.count == 5)
        #expect(request.source == .deck(Fixtures.fullDeck.id))
    }

    @Test("a deck picked from the list is shown until something is next practised, and matching needs five words")
    func choosing() async {
        let (home, log) = await makeHome()
        home.send(.chooseSourceTapped)
        #expect(home.state.isChoosingSource)
        home.send(.sourceChosen(.deck(Fixtures.smallDeck.id)))
        #expect(!home.state.isChoosingSource)
        #expect(home.state.current == .deck(Fixtures.smallDeck.id))
        #expect(!home.state.canStart(.matching))
        #expect(home.state.canStart(.speaking))
        home.send(.continueTapped(.matching))
        home.send(.continueTapped(.speaking))
        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestSpeaking(let request) = log.effects.first else {
            Issue.record("expected a speaking request")
            return
        }
        #expect(request.source == .deck(Fixtures.smallDeck.id))

        try? await repository.recordResults(LessonResults(misses: [:], cleanSolves: [Fixtures.water.id: 1], source: .folder(Fixtures.starter.id)))
        #expect(await waitUntil { home.state.current == .folder(Fixtures.starter.id) })
        #expect(home.state.chosen == nil)
    }

    @Test("with skip learnt words on, quick practice and carrying on leave learnt words out, read afresh on each appearance")
    func skippingLearnt() async throws {
        try await repository.setLearnt(wordID: Fixtures.water.id, isLearnt: true)
        let (home, log) = await makeHome()
        #expect(await waitUntil { home.state.vocabulary.words.contains { $0.isLearnt } })
        #expect(home.state.usableWordCount == 5)

        lessonSettings.setSkipsLearntWords(true)
        home.send(.appeared)
        #expect(home.state.usableWordCount == 4)
        #expect(!home.state.canStartQuickPractice)
        home.send(.sourceChosen(.deck(Fixtures.fullDeck.id)))
        #expect(home.state.currentWordCount == 4)
        home.send(.continueTapped(.flashcards))
        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestFlashcards(let request) = log.effects.first else {
            Issue.record("expected a flash card request")
            return
        }
        #expect(!request.pool.contains { $0.id == Fixtures.water.id })
        // The mistakes list still drills a learnt word.
        #expect(home.state.mistakeWords.count == 3)
    }

    @Test("quick practice asks for a matching lesson over every usable word")
    func quickPractice() async {
        let (home, log) = await makeHome()
        home.send(.quickPracticeTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestMatching(let request) = log.effects.first else {
            Issue.record("expected a matching request")
            return
        }
        #expect(request.title == "All words")
        #expect(request.pool.count == 5)
        // From across the vocabulary, so it is no deck to carry on with.
        #expect(request.source == nil)
    }

    @Test("practising mistakes asks for a speaking lesson, worst first, with no floor")
    func practiseMistakes() async {
        let (home, log) = await makeHome()
        home.send(.practiseMistakesTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestSpeaking(let request) = log.effects.first else {
            Issue.record("expected a drill request")
            return
        }
        #expect(request.pool.map(\.english) == ["mobile phone", "book", "tea"])
    }

    @Test("clearing mistakes asks first")
    func clearingMistakes() async {
        let (home, _) = await makeHome()
        home.send(.clearMistakesTapped)
        #expect(home.state.isConfirmingClear)
        home.send(.clearMistakesCancelled)
        await settle()
        #expect(await repository.writes.isEmpty)

        home.send(.clearMistakesTapped)
        home.send(.clearMistakesConfirmed)
        #expect(await waitUntil { home.state.mistakeWords.isEmpty })
    }

    @Test("the quick practice round count is asked again on every return")
    func roundsReread() async {
        let (home, _) = await makeHome()
        #expect(home.state.quickPracticeRounds == 10)

        home.send(.disappeared)
        rounds.value = 15
        home.send(.appeared)

        #expect(home.state.quickPracticeRounds == 15)
    }

    @Test("changes made while away show on return")
    func reappearing() async {
        let (home, _) = await makeHome()
        home.send(.disappeared)
        await repository.replace(.empty)
        await settle()
        #expect(home.state.vocabulary == Fixtures.vocabulary)

        home.send(.appeared)
        #expect(await waitUntil { home.state.vocabulary == .empty })
    }

}

@MainActor
private final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}
