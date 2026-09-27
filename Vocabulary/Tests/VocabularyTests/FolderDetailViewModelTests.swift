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
            renameFolder: RenameFolderUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository)
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
        empty.send(.namingTapped(.newDeck))
        #expect(empty.state.naming == .newDeck)
        empty.send(.newNameChanged(" Colours "))
        empty.send(.namingConfirmed)
        #expect(empty.state.naming == nil)

        empty.send(.namingTapped(.newFolder))
        empty.send(.newNameChanged("More"))
        empty.send(.namingConfirmed)

        #expect(await waitUntil {
            await repository.writes == ["createDeck Colours inside Empty", "createFolder More inside Empty"]
        })
        #expect(await waitUntil { empty.state.decks.map(\.name) == ["Colours"] })
        #expect(empty.state.subfolders.map(\.folder.name) == ["More"])
    }

    @Test("the folder's name and decks show at once from the snapshot it was opened with")
    func seeded() {
        let viewModel = FolderDetailViewModel(
            folderID: Fixtures.level1.id,
            minimumMatchingWords: 5,
            vocabulary: Fixtures.nested,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository)
        )
        #expect(viewModel.state.title == "Level 1")
        #expect(viewModel.state.decks.map(\.name) == ["Part 1", "Part 2"])
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

    @Test("deleting a subfolder with anything inside asks first, then takes it all")
    func deletingASubfolder() async {
        let (hsk, _) = await makeDetail(Fixtures.hsk.id)
        hsk.send(.deleteFolderTapped(Fixtures.level1.id))
        #expect(hsk.state.deletionWarning == "Level 1 and the 2 decks inside it will be deleted. Their words stay in the library.")
        hsk.send(.deleteFolderCancelled)
        await settle()
        #expect(await repository.writes.isEmpty)

        hsk.send(.deleteFolderTapped(Fixtures.level1.id))
        hsk.send(.deleteFolderConfirmed)
        #expect(hsk.state.subfolders.isEmpty)
        #expect(await waitUntil { await repository.snapshot.decks.map(\.name) == ["Full"] })
    }

    @Test("an empty subfolder goes without asking, and a failed delete puts it back")
    func deletingAnEmptySubfolder() async {
        await repository.replace(Fixtures.nested.movingFolder(Fixtures.emptyFolder.id, into: Fixtures.hsk.id, at: nil))
        let (hsk, log) = await makeDetail(Fixtures.hsk.id)
        await repository.failWrites()
        hsk.send(.deleteFolderTapped(Fixtures.emptyFolder.id))

        #expect(hsk.state.pendingFolderDeletion == nil)
        #expect(await log.contains(.showError(.deleteFolderFailed(FakeVocabularyRepository.failure))))
        #expect(hsk.state.subfolders.map(\.folder.name) == ["Level 1", "Empty"])
    }

    @Test("renaming starts from the folder's name and saves what was typed")
    func renaming() async {
        let (level1, _) = await makeDetail(Fixtures.level1.id)
        level1.send(.namingTapped(.rename))
        #expect(level1.state.newName == "Level 1")
        level1.send(.newNameChanged("HSK 1"))
        level1.send(.namingConfirmed)

        #expect(await waitUntil { await repository.writes == ["renameFolder HSK 1"] })
        #expect(await waitUntil { level1.state.title == "HSK 1" })
    }

    @Test("practising a subfolder draws from everything beneath it, and one too small does not start")
    func practisingASubfolder() async {
        let (hsk, log) = await makeDetail(Fixtures.hsk.id)
        await repository.replace(Fixtures.nested.movingFolder(Fixtures.emptyFolder.id, into: Fixtures.hsk.id, at: nil))
        #expect(await waitUntil { hsk.state.subfolders.count == 2 })
        hsk.send(.practiseFolderTapped(Fixtures.emptyFolder.id))
        hsk.send(.practiseFolderTapped(Fixtures.level1.id))

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .startLesson(let request) = log.effects.first else {
            Issue.record("expected a lesson request")
            return
        }
        #expect(request.title == "Level 1")
        #expect(request.pool.count == 5)
    }
}
