import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyUI

@Suite("Library")
@MainActor
struct LibraryViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.nested)

    private func makeLibrary() async -> (LibraryViewModel, EffectLog<LibraryEffect>) {
        let viewModel = LibraryViewModel(
            minimumMatchingWords: 5,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            moveFolder: MoveFolderUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        let current = await repository.snapshot
        #expect(await waitUntil { viewModel.state.vocabulary == current })
        return (viewModel, log)
    }

    @Test("choosing somewhere else in the sidebar closes the open deck, going back clears both")
    func selection() async {
        let (library, _) = await makeLibrary()
        library.send(.selected(.folder(Fixtures.level1.id)))
        library.send(.deckOpened(Fixtures.part1.id))
        library.send(.selected(.folder(Fixtures.level1.id)))
        #expect(library.state.openDeck == Fixtures.part1.id)

        library.send(.selected(.topLevelDecks))
        #expect(library.state.openDeck == nil)

        library.send(.deckOpened(Fixtures.fullDeck.id))
        library.send(.selected(nil))
        #expect(library.state.selection == nil)
        #expect(library.state.openDeck == nil)
    }

    @Test("dragging a folder moves it at once and saves where it landed")
    func dragging() async {
        let (library, _) = await makeLibrary()
        library.send(.folderMoved(id: Fixtures.emptyFolder.id, parentID: Fixtures.hsk.id, index: 0))

        #expect(library.state.vocabulary.folders(in: Fixtures.hsk.id).map(\.name) == ["Empty", "Level 1"])
        #expect(await waitUntil { await repository.writes == ["moveFolder Empty to HSK at 0"] })
    }

    @Test("a drag that would put a folder inside itself changes nothing")
    func draggingIntoItself() async {
        let (library, _) = await makeLibrary()
        library.send(.folderMoved(id: Fixtures.hsk.id, parentID: Fixtures.level1.id, index: 0))
        await settle()

        #expect(library.state.vocabulary == Fixtures.nested)
        #expect(await repository.writes.isEmpty)
    }

    @Test("a failed move puts the folder back and says why")
    func failedMove() async {
        let (library, log) = await makeLibrary()
        await repository.failWrites()
        library.send(.folderMoved(id: Fixtures.level1.id, parentID: nil, index: 0))

        #expect(await log.contains(.showError(.moveFolderFailed(FakeVocabularyRepository.failure))))
        #expect(library.state.vocabulary.folder(id: Fixtures.level1.id)?.parentID == Fixtures.hsk.id)
    }

    @Test("a folder can be made at the top or inside another, and renamed from its menu")
    func namingFolders() async {
        let (library, _) = await makeLibrary()
        library.send(.newFolderTapped(parentID: nil))
        #expect(library.state.namingTitle == "New folder")
        library.send(.nameChanged("HSK 2"))
        library.send(.namingConfirmed)

        library.send(.newFolderTapped(parentID: Fixtures.hsk.id))
        #expect(library.state.namingMessage == "It goes inside HSK.")
        library.send(.nameChanged("Level 2"))
        library.send(.namingConfirmed)

        library.send(.renameFolderTapped(Fixtures.emptyFolder.id))
        #expect(library.state.namingTitle == "Rename folder")
        #expect(library.state.name == "Empty")
        library.send(.nameChanged("Later"))
        library.send(.namingConfirmed)

        #expect(library.state.naming == nil)
        #expect(await waitUntil {
            await repository.writes == ["createFolder HSK 2", "createFolder Level 2 inside HSK", "renameFolder Later"]
        })
    }

    @Test("deleting a folder with anything inside asks first, and closes what was open inside it")
    func deleting() async {
        let (library, _) = await makeLibrary()
        library.send(.selected(.folder(Fixtures.level1.id)))
        library.send(.deckOpened(Fixtures.part1.id))

        library.send(.deleteFolderTapped(Fixtures.hsk.id))
        #expect(library.state.deletionWarning == "HSK and the 1 folder and 2 decks inside it will be deleted. Their words stay in the library.")
        library.send(.deleteFolderConfirmed)

        #expect(library.state.selection == nil)
        #expect(library.state.openDeck == nil)
        #expect(await waitUntil { await repository.snapshot.folders.map(\.name) == ["Empty"] })
    }

    @Test("an empty folder goes without asking")
    func deletingEmpty() async {
        let (library, _) = await makeLibrary()
        library.send(.deleteFolderTapped(Fixtures.emptyFolder.id))

        #expect(library.state.pendingFolderDeletion == nil)
        #expect(await waitUntil { await repository.writes == ["deleteFolder"] })
    }

    @Test("practising a folder from its menu draws from everything beneath, and an empty one does not start")
    func practising() async {
        let (library, log) = await makeLibrary()
        library.send(.practiseFolderTapped(Fixtures.emptyFolder.id))
        library.send(.practiseFolderTapped(Fixtures.hsk.id))

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestMatching(let request) = log.effects.first else {
            Issue.record("expected a matching request")
            return
        }
        #expect(request.title == "HSK")
        #expect(request.pool.count == 5)
    }
}
