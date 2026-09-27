import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyUI

@Suite("Folder detail")
@MainActor
struct FolderDetailViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.nested)

    private func makeDetail(_ folderID: UUID?) async -> (FolderDetailViewModel, EffectLog<FolderDetailEffect>) {
        let viewModel = FolderDetailViewModel(
            folderID: folderID,
            minimumMatchingWords: 5,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            moveDeck: MoveDeckUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        let current = await repository.snapshot
        #expect(await waitUntil { viewModel.state.vocabulary == current })
        return (viewModel, log)
    }

    @Test("a folder lists its own decks, and the top level lists the loose ones")
    func contents() async {
        let (level1, _) = await makeDetail(Fixtures.level1.id)
        #expect(level1.state.title == "Level 1")
        #expect(level1.state.decks.map(\.name) == ["Part 1", "Part 2"])
        #expect(level1.state.practisesAsWhole)
        #expect(level1.state.canStartLesson)

        let (top, _) = await makeDetail(nil)
        #expect(top.state.title == "Decks")
        #expect(top.state.decks.map(\.name) == ["Full"])
        #expect(!top.state.practisesAsWhole)
    }

    @Test("a folder's lesson draws from every deck beneath it, even with no decks of its own")
    func startingALesson() async {
        let (hsk, log) = await makeDetail(Fixtures.hsk.id)
        #expect(hsk.state.decks.isEmpty)
        hsk.send(.startLessonTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .startLesson(let request) = log.effects.first else {
            Issue.record("expected a lesson request")
            return
        }
        #expect(request.title == "HSK")
        #expect(request.pool.map(\.english) == ["water", "tea", "book", "mobile phone", "green"])
    }

    @Test("a new deck goes in the folder shown, or at the top level")
    func creatingADeck() async {
        let (empty, _) = await makeDetail(Fixtures.emptyFolder.id)
        empty.send(.newDeckTapped)
        #expect(empty.state.isNamingDeck)
        empty.send(.newDeckNameChanged(" Colours "))
        empty.send(.createDeckConfirmed)
        #expect(!empty.state.isNamingDeck)
        #expect(await waitUntil { empty.state.decks.map(\.name) == ["Colours"] })

        let (top, _) = await makeDetail(nil)
        top.send(.newDeckTapped)
        top.send(.newDeckNameChanged("Loose"))
        top.send(.createDeckConfirmed)
        #expect(await waitUntil { await repository.writes == ["createDeck Colours inside Empty", "createDeck Loose"] })
    }

    @Test("dragging a deck reorders it within the folder, in either direction")
    func reordering() async {
        let (level1, _) = await makeDetail(Fixtures.level1.id)
        level1.send(.decksMoved(from: [1], to: 0))
        #expect(level1.state.decks.map(\.name) == ["Part 2", "Part 1"])

        level1.send(.decksMoved(from: [0], to: 2))
        #expect(level1.state.decks.map(\.name) == ["Part 1", "Part 2"])
        #expect(await waitUntil {
            await repository.writes == ["moveDeck Part 2 to Level 1 at 0", "moveDeck Part 2 to Level 1 at 1"]
        })
    }

    @Test("a failed delete puts the deck back and says why")
    func failedDelete() async {
        let (level1, log) = await makeDetail(Fixtures.level1.id)
        await repository.failWrites()
        level1.send(.deleteDeckTapped(Fixtures.part1.id))
        #expect(level1.state.decks.map(\.name) == ["Part 2"])

        #expect(await log.contains(.showError(.deleteDeckFailed(FakeVocabularyRepository.failure))))
        #expect(level1.state.decks.map(\.name) == ["Part 1", "Part 2"])
    }

    @Test("practising a deck below the floor does not start")
    func practisingTooSmall() async {
        let (level1, log) = await makeDetail(Fixtures.level1.id)
        level1.send(.practiseDeckTapped(Fixtures.part2.id))
        await settle()
        #expect(log.effects.isEmpty)
    }
}
