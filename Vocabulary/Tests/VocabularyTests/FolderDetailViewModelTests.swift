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

    private func makeDetail(_ folderID: UUID) async -> (FolderDetailViewModel, EffectLog<FolderDetailEffect>) {
        let viewModel = FolderDetailViewModel(
            folderID: folderID,
            minimumMatchingWords: 5,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            moveDeck: MoveDeckUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        let current = await repository.snapshot
        #expect(await waitUntil { viewModel.state.vocabulary == current })
        return (viewModel, log)
    }

    @Test("a folder shows the folders beneath it as a tree, then its own decks")
    func contents() async {
        let (hsk, _) = await makeDetail(Fixtures.hsk.id)
        #expect(hsk.state.title == "HSK")
        #expect(hsk.state.subfolders.map(\.folder.name) == ["Level 1"])
        #expect(hsk.state.subfolders.first?.deckCount == 2)
        #expect(hsk.state.subfolders.first?.children == nil)
        #expect(hsk.state.decks.isEmpty)
        #expect(hsk.state.summary == "0 decks · 1 folder")

        let (level1, _) = await makeDetail(Fixtures.level1.id)
        #expect(level1.state.subfolders.isEmpty)
        #expect(level1.state.decks.map(\.name) == ["Part 1", "Part 2"])
        #expect(level1.state.summary == "2 decks")
        #expect(level1.state.canStartLesson)
    }

    @Test("folders nest in the tree to any depth")
    func deepTree() async {
        await repository.replace(Fixtures.nested.movingFolder(Fixtures.emptyFolder.id, into: Fixtures.level1.id, at: 0))
        let (hsk, _) = await makeDetail(Fixtures.hsk.id)
        #expect(hsk.state.subfolders.first?.children?.map(\.folder.name) == ["Empty"])
        #expect(hsk.state.summary == "0 decks · 2 folders")
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

    @Test("a new deck or folder goes inside the folder shown")
    func creating() async {
        let (empty, _) = await makeDetail(Fixtures.emptyFolder.id)
        empty.send(.newItemTapped(.deck))
        #expect(empty.state.naming == .deck)
        empty.send(.newNameChanged(" Colours "))
        empty.send(.createConfirmed)
        #expect(empty.state.naming == nil)

        empty.send(.newItemTapped(.folder))
        empty.send(.newNameChanged("More"))
        empty.send(.createConfirmed)

        #expect(await waitUntil {
            await repository.writes == ["createDeck Colours inside Empty", "createFolder More inside Empty"]
        })
        #expect(await waitUntil { empty.state.decks.map(\.name) == ["Colours"] })
        #expect(empty.state.subfolders.map(\.folder.name) == ["More"])
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
