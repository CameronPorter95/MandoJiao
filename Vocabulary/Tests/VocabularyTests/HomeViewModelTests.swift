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
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)
    private let rounds = Box(10)

    private func makeHome() async -> (HomeViewModel, EffectLog<HomeEffect>) {
        let viewModel = HomeViewModel(
            minimumMatchingWords: 5,
            quickPracticeRounds: { rounds.value },
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository),
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
        home.send(.newItemTapped(.deck))
        #expect(home.state.naming == .deck)
        home.send(.newItemNameChanged("  Colours "))
        home.send(.createConfirmed)

        #expect(home.state.naming == nil)
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

    @Test("a new folder is created with the typed name")
    func creatingAFolder() async {
        let (home, _) = await makeHome()
        home.send(.newItemTapped(.folder))
        #expect(home.state.naming == .folder)
        home.send(.newItemNameChanged("HSK"))
        home.send(.createConfirmed)

        #expect(await waitUntil { await repository.writes == ["createFolder HSK"] })
        #expect(await waitUntil { home.state.folders.map(\.name) == ["HSK"] })
    }

    @Test("home lists top-level folders then decks, and a folder practises every word beneath it")
    func folders() async {
        let (home, log) = await makeHome()
        await repository.replace(Fixtures.nested)
        #expect(await waitUntil { home.state.vocabulary == Fixtures.nested })

        #expect(home.state.folders.map(\.name) == ["HSK", "Empty"])
        #expect(home.state.decks.map(\.name) == ["Full"])
        #expect(home.state.vocabulary.subtitle(for: Fixtures.hsk, minimumMatchingWords: 5) == "1 folder, 5 words")
        #expect(home.state.vocabulary.subtitle(for: Fixtures.level1, minimumMatchingWords: 5) == "2 decks, 5 words")
        #expect(home.state.vocabulary.subtitle(for: Fixtures.emptyFolder, minimumMatchingWords: 5) == "Empty")

        home.send(.practiseFolderTapped(Fixtures.hsk.id))
        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestMatching(let request) = log.effects.first else {
            Issue.record("expected a matching request")
            return
        }
        #expect(request.title == "HSK")
        #expect(request.pool.map(\.english) == ["water", "tea", "book", "mobile phone", "green"])
    }

    @Test("deleting a folder with anything inside asks first, then takes it all")
    func deletingAFolder() async {
        let (home, _) = await makeHome()
        await repository.replace(Fixtures.nested)
        #expect(await waitUntil { home.state.vocabulary == Fixtures.nested })

        home.send(.deleteFolderTapped(Fixtures.hsk.id))
        #expect(home.state.deletionWarning == "HSK and the 1 folder and 2 decks inside it will be deleted. Their words stay in the library.")
        home.send(.deleteFolderCancelled)
        await settle()
        #expect(await repository.writes.isEmpty)

        home.send(.deleteFolderTapped(Fixtures.hsk.id))
        home.send(.deleteFolderConfirmed)
        #expect(home.state.pendingFolderDeletion == nil)
        #expect(home.state.vocabulary.folders.map(\.name) == ["Empty"])
        #expect(home.state.vocabulary.decks.map(\.name) == ["Full"])
        #expect(await waitUntil { await repository.snapshot.decks.map(\.name) == ["Full"] })
    }

    @Test("deleting an empty folder does not ask")
    func deletingAnEmptyFolder() async {
        let (home, _) = await makeHome()
        await repository.replace(Fixtures.nested)
        #expect(await waitUntil { home.state.vocabulary == Fixtures.nested })

        home.send(.deleteFolderTapped(Fixtures.emptyFolder.id))
        #expect(home.state.pendingFolderDeletion == nil)
        #expect(await waitUntil { await repository.writes == ["deleteFolder"] })
    }
}

@MainActor
private final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}
