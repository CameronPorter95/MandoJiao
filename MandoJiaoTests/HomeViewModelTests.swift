import Foundation
import Testing
@testable import MandoJiao

@Suite("Home")
@MainActor
struct HomeViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)

    private func makeHome() async -> (HomeViewModel, EffectLog<HomeEffect>) {
        let viewModel = HomeViewModel(
            minimumMatchingWords: 5,
            quickPracticeRounds: 10,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
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
    }

    @Test("practising mistakes asks for a drill, worst first, with no floor")
    func practiseMistakes() async {
        let (home, log) = await makeHome()
        home.send(.practiseMistakesTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestDrill(let request) = log.effects.first else {
            Issue.record("expected a drill request")
            return
        }
        #expect(request.pool.map(\.english) == ["mobile phone", "book", "tea"])
    }

    @Test("a deck below the matching floor does not start")
    func smallDeck() async {
        let (home, log) = await makeHome()
        #expect(!home.state.canStartLesson(with: Fixtures.smallDeck))
        #expect(home.state.subtitle(for: Fixtures.smallDeck) == "1 words, needs 5")

        home.send(.practiseDeckTapped(Fixtures.smallDeck.id))
        home.send(.practiseDeckTapped(Fixtures.fullDeck.id))

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestMatching(let request) = log.effects.first else {
            Issue.record("expected a matching request")
            return
        }
        #expect(request.title == "Full")
    }

    @Test("a new deck is created with the typed name")
    func creatingADeck() async {
        let (home, _) = await makeHome()
        home.send(.newDeckTapped)
        #expect(home.state.isNamingDeck)
        home.send(.newDeckNameChanged("  Colours "))
        home.send(.createDeckConfirmed)

        #expect(!home.state.isNamingDeck)
        #expect(await waitUntil { await repository.writes == ["createDeck Colours"] })
        #expect(await waitUntil { home.state.vocabulary.decks.count == 3 })
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

    @Test("a failed deck delete puts the deck back and says why")
    func failedDelete() async {
        let (home, log) = await makeHome()
        await repository.failWrites()

        home.send(.deleteDeckTapped(Fixtures.fullDeck.id))
        #expect(home.state.vocabulary.decks.count == 1)

        #expect(await log.contains(.showError(.deleteDeckFailed(FakeVocabularyRepository.failure))))
        #expect(home.state.vocabulary.decks.count == 2)
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
