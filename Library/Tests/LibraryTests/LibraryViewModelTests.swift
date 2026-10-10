import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import CoreUI
import LibraryTestSupport
@testable import LibraryDomain
@testable import LibraryUI

@Suite("Library")
@MainActor
struct LibraryViewModelTests {
    private let lessonSettings = FakeLessonSettings()
    private let repository = FakeVocabularyRepository(Fixtures.nested)
    private let layout = FakeLibraryLayoutRepository()

    private func makeLibrary() async -> (LibraryViewModel, EffectLog<LibraryEffect>) {
        let viewModel = LibraryViewModel(
            minimumMatchingWords: 5,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: GetLessonSettingsUseCase(repository: lessonSettings),
            createFolder: CreateFolderUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            moveFolder: MoveFolderUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository),
            getLayout: GetLibraryLayoutUseCase(repository: layout),
            saveLayout: SaveLibraryLayoutUseCase(repository: layout)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        let current = await repository.snapshot
        #expect(await waitUntil { viewModel.state.vocabulary == current })
        return (viewModel, log)
    }

    @Test("driven, the selection and each pushed page come to the front, and back pops the stack")
    func driverFront() async throws {
        let (library, _) = await makeLibrary()
        let driver = library.driver(
            navigation: LibraryTabNavigation(didRequestMatching: { _ in }, didRequestFlashcards: { _ in }, didRequestSpeaking: { _ in }),
            root: { _, _ in probe("root") },
            page: { page, _ in
                switch page {
                case .folder: probe("folder")
                case .deck: probe("deck")
                }
            }
        )
        #expect(driver.front() == nil)

        try driver.send("selected", Data(#"{"_0":{"folder":{"_0":"\#(Fixtures.hsk.id)"}}}"#.utf8))
        #expect(driver.front()?.name == "root")
        try driver.send("opened", Data(#"{"_0":{"deck":{"_0":"\#(Fixtures.part1.id)"}}}"#.utf8))
        #expect(driver.front()?.name == "deck")

        #expect(driver.back())
        #expect(driver.front()?.name == "root")
        // Then back to the sidebar, as on iPhone.
        #expect(driver.back())
        #expect(driver.front() == nil)
        #expect(!driver.back())
    }

    @Test("driven, open finds a folder or deck by name, key or id, as tapping its row would")
    func driverOpens() async throws {
        let (library, _) = await makeLibrary()
        let driver = library.driver(navigation: LibraryTabNavigation(
            didRequestMatching: { _ in }, didRequestFlashcards: { _ in }, didRequestSpeaking: { _ in }
        ))

        try driver.open("folder", "hsk")
        #expect(library.state.selection == .folder(Fixtures.hsk.id))
        // Each twice: one already in front is not pushed again, or the copy hides under it and
        // a back pops it with nothing to show for it.
        try driver.open("folder", "Level 1")
        try driver.open("folder", "Level 1")
        try driver.open("deck", String(Fixtures.part1.id.uuidString.prefix(8)))
        try driver.open("deck", "Part 1")
        #expect(library.state.path == [.folder(Fixtures.level1.id), .deck(Fixtures.part1.id)])

        #expect(throws: ScreenDriverError.notFound("deck", "nope")) { try driver.open("deck", "nope") }
        #expect(throws: ScreenDriverError.cannotOpen("word")) { try driver.open("word", "水") }
        // Nothing in front of it without builders: in the app, the views hold the stack.
        #expect(driver.front() == nil)
    }

    @Test("driven, a search's results, the word editor and the HSK levels come to the front, and close")
    func driverSheetsAndResults() async throws {
        let (library, _) = await makeLibrary()
        let handedOn = Box<[String]>([])
        var dismissEditor: (() -> Void)?
        var dismissLevels: (() -> Void)?
        let driver = library.driver(
            navigation: LibraryTabNavigation(didRequestMatching: { _ in }, didRequestFlashcards: { _ in }, didRequestSpeaking: { _ in }),
            root: { _, _ in probe("root") },
            page: { _, _ in probe("page") },
            results: { text, _ in
                handedOn.value.append("built with \(text)")
                return recordingProbe("results", into: handedOn)
            },
            editor: { _, dismissed in
                dismissEditor = dismissed
                return probe("editor")
            },
            hskLevels: { dismissed in
                dismissLevels = dismissed
                return probe("hsk levels")
            }
        )

        try driver.send("searchPresentedChanged", Data(#"{"_0":true}"#.utf8))
        #expect(driver.front()?.name == "results")
        try driver.send("searchChanged", Data(#"{"_0":"wa"}"#.utf8))
        _ = driver.front()
        _ = driver.front()
        // Built with the text so far, then handed each change once.
        #expect(handedOn.value == ["built with ", "searchChanged wa"])

        try driver.send("newWordTapped", nil)
        #expect(driver.front()?.name == "editor")
        dismissEditor?()
        #expect(library.state.editor == nil)
        #expect(driver.front()?.name == "results")

        try driver.send("hskLevelsTapped", nil)
        #expect(driver.front()?.name == "hsk levels")
        dismissLevels?()
        #expect(!library.state.isShowingHSKLevels)

        // Back closes the search before anything else.
        try driver.send("selected", Data(#"{"_0":{"folder":{"_0":"\#(Fixtures.hsk.id)"}}}"#.utf8))
        try driver.send("searchPresentedChanged", Data(#"{"_0":true}"#.utf8))
        #expect(driver.back())
        #expect(!library.state.isSearching)
        #expect(driver.front()?.name == "root")
    }

    @Test("driven by name, every listed action is accepted")
    func driverAcceptsEveryAction() async {
        // Unknown ids, so nothing is really changed in the shared fixture.
        let id = UUID().uuidString
        let page = #"{"_0":{"deck":{"_0":"\#(id)"}}}"#
        let arguments = [
            "selected": page.replacingOccurrences(of: "deck", with: "folder"), "opened": page,
            "pathChanged": #"{"_0":[{"deck":{"_0":"\#(id)"}}]}"#,
            "folderExpanded": #"{"_0":"\#(id)","_1":true,"in":{"tree":{}}}"#,
            "folderSectionToggled": #"{"_0":"\#(id)","_1":"decks"}"#,
            "deckSortChanged": #"{"_0":"\#(id)","_1":{"field":"title","ascending":true}}"#,
            "wordSortChanged": #"{"_0":{"field":"pinyin","ascending":true}}"#,
            "searchPresentedChanged": #"{"_0":true}"#, "searchChanged": #"{"_0":"wa"}"#,
            "folderMoved": #"{"id":"\#(id)","parentID":null,"index":0}"#, "newFolderTapped": #"{"parentID":null}"#,
            "renameFolderTapped": #"{"_0":"\#(id)"}"#, "nameChanged": #"{"_0":"x"}"#,
            "practiseFolderTapped": #"{"_0":"\#(id)"}"#, "deleteFolderTapped": #"{"_0":"\#(id)"}"#,
        ]
        for name in LibraryAction.names {
            let (library, _) = await makeLibrary()
            let driver = library.driver(
                navigation: LibraryTabNavigation(didRequestMatching: { _ in }, didRequestFlashcards: { _ in }, didRequestSpeaking: { _ in }),
                root: { _, _ in probe("root") }, page: { _, _ in probe("page") }
            )
            #expect(throws: Never.self) { try driver.send(name, arguments[name].map { Data($0.utf8) }) }
        }
    }

    @Test("folders and decks opened from a folder push onto its stack, and the sidebar starts a new one")
    func stack() async {
        let (library, _) = await makeLibrary()
        library.send(.selected(.folder(Fixtures.hsk.id)))
        library.send(.opened(.folder(Fixtures.level1.id)))
        library.send(.opened(.deck(Fixtures.part1.id)))
        #expect(library.state.path == [.folder(Fixtures.level1.id), .deck(Fixtures.part1.id)])

        library.send(.pathChanged([.folder(Fixtures.level1.id)]))
        #expect(library.state.path == [.folder(Fixtures.level1.id)])

        library.send(.selected(.folder(Fixtures.starter.id)))
        #expect(library.state.path.isEmpty)

        library.send(.opened(.deck(Fixtures.fullDeck.id)))
        library.send(.selected(nil))
        #expect(library.state.selection == nil)
        #expect(library.state.path.isEmpty)
    }

    @Test("a page whose folder or deck is deleted is popped, with everything above it")
    func pruning() async {
        let (library, _) = await makeLibrary()
        library.send(.selected(.folder(Fixtures.hsk.id)))
        library.send(.opened(.folder(Fixtures.level1.id)))
        library.send(.opened(.deck(Fixtures.part1.id)))

        await repository.replace(Vocabulary(
            words: Fixtures.words,
            decks: [Fixtures.fullDeck, Fixtures.part2],
            folders: [Fixtures.starter, Fixtures.hsk, Fixtures.level1]
        ))
        #expect(await waitUntil { library.state.path == [.folder(Fixtures.level1.id)] })
    }

    @Test("opening the search shows the words in place of the tree, before anything is typed, until it closes")
    func searching() async {
        let (library, _) = await makeLibrary()
        #expect(!library.state.isSearching)

        library.send(.searchPresentedChanged(true))
        #expect(library.state.isSearching)
        #expect(library.state.searchText == "")

        library.send(.searchChanged("shui"))
        #expect(library.state.searchText == "shui")

        library.send(.searchChanged(""))
        library.send(.searchPresentedChanged(false))
        #expect(!library.state.isSearching)
    }

    @Test("a new word opens a blank editor from the library, which has no list of words to add from")
    func newWord() async {
        let (library, _) = await makeLibrary()
        library.send(.newWordTapped)
        #expect(library.state.editor == .new(WordDraft()))

        library.send(.editorDismissed)
        #expect(library.state.editor == nil)
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
        library.send(.selected(.folder(Fixtures.hsk.id)))
        library.send(.opened(.deck(Fixtures.part1.id)))

        library.send(.deleteFolderTapped(Fixtures.hsk.id))
        #expect(library.state.deletionWarning == "HSK and the 1 folder and 2 decks inside it will be deleted. Their words stay in your vocabulary.")
        library.send(.deleteFolderConfirmed)

        #expect(library.state.selection == nil)
        #expect(library.state.path.isEmpty)
        #expect(await waitUntil { await repository.snapshot.folders.map(\.name) == ["Starter", "Empty"] })
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

    @Test("the tree and each folder's screen unfold independently, and every change is saved")
    func expansion() async {
        let (library, _) = await makeLibrary()
        #expect(library.state.layout == LibraryLayout())

        library.send(.folderExpanded(Fixtures.hsk.id, true, in: .tree))
        library.send(.folderExpanded(Fixtures.level1.id, true, in: .folder(Fixtures.hsk.id)))
        library.send(.folderSectionToggled(Fixtures.level1.id, .decks))

        #expect(library.state.layout.expanded(in: .tree) == [Fixtures.hsk.id])
        #expect(library.state.layout.expanded(in: .folder(Fixtures.hsk.id)) == [Fixtures.level1.id])
        #expect(library.state.layout.expanded(in: .folder(Fixtures.level1.id)).isEmpty)
        #expect(library.state.layout.isFolded(.decks, in: Fixtures.level1.id))
        library.send(.deckSortChanged(Fixtures.level1.id, DeckSort(field: .title, ascending: true)))
        #expect(library.state.layout.deckSort(in: Fixtures.level1.id).field == .title)
        #expect(layout.saves == 4)
        #expect(layout.layout() == library.state.layout)
    }

    @Test("the word list's sort is the library's to save, alongside the rest of the layout")
    func wordSort() async {
        let (library, _) = await makeLibrary()
        library.send(.deckSortChanged(Fixtures.level1.id, DeckSort(field: .title, ascending: true)))
        library.send(.wordSortChanged(WordSort(field: .pinyin, ascending: true)))
        #expect(layout.layout().wordSort == WordSort(field: .pinyin, ascending: true))
        #expect(layout.layout().deckSort(in: Fixtures.level1.id).field == .title)
    }

    @Test("the library opens as it was left")
    func restoring() async {
        layout.save(LibraryLayout().settingExpanded(Fixtures.hsk.id, true, in: .tree))
        let (library, _) = await makeLibrary()
        #expect(library.state.layout.expanded(in: .tree) == [Fixtures.hsk.id])
    }

    @Test("the tree offers to practise only a folder with enough words beneath it")
    func practisable() async {
        let (library, _) = await makeLibrary()
        #expect(library.state.canPractise(Fixtures.hsk.id))
        #expect(!library.state.canPractise(Fixtures.emptyFolder.id))
        #expect(!library.state.canPractise(UUID()))
    }

    @Test("HSK levels opens as a sheet and closes")
    func hskLevels() async {
        let (library, _) = await makeLibrary()
        library.send(.hskLevelsTapped)
        #expect(library.state.isShowingHSKLevels)
        library.send(.hskLevelsDismissed)
        #expect(!library.state.isShowingHSKLevels)
    }
}

/// A screen that only takes appearing and disappearing, standing in for a library page.
@MainActor
private func probe(_ name: String) -> ScreenDriver {
    ScreenDriver(
        name: name, actions: ["appeared", "disappeared"], state: { name }, summary: { $0 },
        send: { (_: ProbeLifecycle) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
    )
}

private enum ProbeLifecycle: Decodable {
    case appeared, disappeared
}

@MainActor
private final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

/// A results screen that records the search text handed on to it.
@MainActor
private func recordingProbe(_ name: String, into log: Box<[String]>) -> ScreenDriver {
    ScreenDriver(
        name: name, actions: ["appeared", "disappeared", "searchChanged"], state: { name }, summary: { $0 },
        send: { (action: ProbeSearch) in
            if case .searchChanged(let text) = action { log.value.append("searchChanged \(text)") }
        },
        effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
    )
}

private enum ProbeSearch: Decodable {
    case appeared, disappeared
    case searchChanged(text: String)
}
