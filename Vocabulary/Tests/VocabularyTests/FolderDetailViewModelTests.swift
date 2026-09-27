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

    private func makeDetail(_ folder: FolderSummary) async -> (FolderDetailViewModel, EffectLog<FolderDetailEffect>) {
        let viewModel = FolderDetailViewModel(
            folderID: folder.id,
            minimumMatchingWords: 5,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            moveFolder: MoveFolderUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository),
            renameDelay: .milliseconds(30)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.name != nil }
        return (viewModel, log)
    }

    @Test("a folder lists what is inside, and says where it lives")
    func contents() async {
        let (level1, _) = await makeDetail(Fixtures.level1)
        #expect(level1.state.title == "Level 1")
        #expect(level1.state.folders.isEmpty)
        #expect(level1.state.decks.map(\.name) == ["Part 1", "Part 2"])
        #expect(level1.state.location == "HSK")
        #expect(level1.state.canStartLesson)

        let (empty, _) = await makeDetail(Fixtures.emptyFolder)
        #expect(empty.state.isEmpty)
        #expect(!empty.state.canStartLesson)
    }

    @Test("starting a lesson draws from every deck beneath, under the typed name")
    func startingALesson() async {
        let (hsk, log) = await makeDetail(Fixtures.hsk)
        hsk.send(.nameChanged("HSK 3.0"))
        hsk.send(.startLessonTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .startLesson(let request) = log.effects.first else {
            Issue.record("expected a lesson request")
            return
        }
        #expect(request.title == "HSK 3.0")
        #expect(request.pool.map(\.english) == ["water", "tea", "book", "mobile phone", "green"])
        #expect(await waitUntil { await repository.writes == ["renameFolder HSK 3.0"] })
    }

    @Test("a deck or a folder can be made inside")
    func creatingInside() async {
        let (empty, _) = await makeDetail(Fixtures.emptyFolder)
        empty.send(.newItemTapped(.deck))
        #expect(empty.state.naming == .deck)
        empty.send(.newItemNameChanged("Colours"))
        empty.send(.createConfirmed)
        empty.send(.newItemTapped(.folder))
        empty.send(.newItemNameChanged("More"))
        empty.send(.createConfirmed)

        #expect(await waitUntil {
            await repository.writes == ["createDeck Colours inside Empty", "createFolder More inside Empty"]
        })
        #expect(await waitUntil { empty.state.decks.map(\.name) == ["Colours"] && empty.state.folders.map(\.name) == ["More"] })
    }

    @Test("a folder moves only where it would not end up inside itself")
    func moving() async {
        let (hsk, _) = await makeDetail(Fixtures.hsk)
        #expect(hsk.state.destinations.map(\.title) == ["Empty"])

        let (level1, _) = await makeDetail(Fixtures.level1)
        #expect(level1.state.destinations.map(\.title) == ["Top level", "Empty"])
        level1.send(.moveTapped)
        level1.send(.destinationChosen(nil))

        #expect(level1.state.location == "Top level")
        #expect(await waitUntil { await repository.writes == ["moveFolder Level 1 to top level"] })
    }

    @Test("with nowhere to move, the folder says so")
    func nowhereToMove() async {
        await repository.replace(Vocabulary(words: Fixtures.words, decks: [], folders: [Fixtures.emptyFolder]))
        let (empty, _) = await makeDetail(Fixtures.emptyFolder)
        #expect(empty.state.moveUnavailableReason == "Make another folder first to move this one into.")
    }

    @Test("a failed move puts the folder back and says why")
    func failedMove() async {
        let (level1, log) = await makeDetail(Fixtures.level1)
        await repository.failWrites()
        level1.send(.destinationChosen(nil))
        #expect(level1.state.folder?.parentID == nil)

        #expect(await log.contains(.showError(.moveFolderFailed(FakeVocabularyRepository.failure))))
        #expect(level1.state.folder?.parentID == Fixtures.hsk.id)
    }

    @Test("deleting a folder inside asks first when it holds anything, and a deck goes at once")
    func deleting() async {
        let (hsk, _) = await makeDetail(Fixtures.hsk)
        hsk.send(.deleteFolderTapped(Fixtures.level1.id))
        #expect(hsk.state.deletionWarning == "Level 1 and the 2 decks inside it will be deleted. Their words stay in the library.")
        hsk.send(.deleteFolderConfirmed)
        #expect(hsk.state.isEmpty)
        #expect(await waitUntil { await repository.snapshot.decks.map(\.name) == ["Full"] })
    }

    @Test("deleting a deck inside does not ask")
    func deletingADeck() async {
        let (level1, _) = await makeDetail(Fixtures.level1)
        level1.send(.deleteDeckTapped(Fixtures.part1.id))

        #expect(level1.state.decks.map(\.name) == ["Part 2"])
        #expect(await waitUntil { await repository.writes == ["deleteDeck"] })
    }

    @Test("practising a deck inside below the floor does not start")
    func practisingTooSmall() async {
        let (level1, log) = await makeDetail(Fixtures.level1)
        level1.send(.practiseDeckTapped(Fixtures.part2.id))
        await settle()
        #expect(log.effects.isEmpty)
    }
}
