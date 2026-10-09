import DictionaryDomain
import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import CoreUI
import LibraryTestSupport
@testable import LibraryDomain
@testable import LibraryData
@testable import LibraryUI

@Suite("Word library")
@MainActor
struct WordLibraryViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)

    private func makeLibrary() async -> (WordLibraryViewModel, EffectLog<WordLibraryEffect>) {
        let viewModel = WordLibraryViewModel(
            folderID: nil,
            vocabulary: .empty,
            sort: .default,
            searchText: "",
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            setLearnt: SetWordLearntUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.vocabulary == Fixtures.vocabulary }
        return (viewModel, log)
    }

    @Test("driven by name, every listed action is accepted")
    func driverAcceptsEveryAction() async {
        let arguments = [
            "searchChanged": #"{"text":"sh"}"#, "sortChanged": #"{"sort":{"field":"pinyin","ascending":true}}"#,
            "editTapped": #"{"word":0}"#, "dictionaryTapped": #"{"word":0}"#, "deleteTapped": #"{"word":99}"#,
            "learntToggled": #"{"word":99}"#,
        ]
        for name in ["appeared", "disappeared", "searchChanged", "sortChanged", "editTapped", "editorDismissed",
                     "dictionaryTapped", "dictionaryDismissed", "deleteTapped", "learntToggled"] {
            let (library, _) = await makeLibrary()
            let driver = library.driver(layout: WordListLayout(sort: .default, setSort: { _ in }))
            #expect(driver.actions.contains(name))
            #expect(throws: Never.self) { try driver.send(name, arguments[name].map { Data($0.utf8) }) }
        }
    }

    @Test("driven, a word is opened by its place in the list, with the editor in front until it closes")
    func driverOpensByPlace() async throws {
        var sorts: [WordSort] = []
        var dismiss: (() -> Void)?
        let (library, _) = await makeLibrary()
        let driver = library.driver(layout: WordListLayout(sort: .default, setSort: { sorts.append($0) })) { target, dismissed in
            dismiss = dismissed
            return Self.probe("editor \(target.id)")
        }
        try driver.send("searchChanged", Data(#"{"text":"sh"}"#.utf8))
        let first = library.state.words[0]
        #expect(driver.summary().hasPrefix("results  3 of 6 words  0. \(first.hanzi)"))

        try driver.send("editTapped", Data(#"{"word":0}"#.utf8))
        #expect(driver.front()?.name == "editor \(first.id.uuidString)")
        dismiss?()
        #expect(driver.front() == nil)

        // Past the end of the list: nothing happens.
        try driver.send("editTapped", Data(#"{"word":9}"#.utf8))
        #expect(library.state.editor == nil)

        let byPinyin = WordSort(field: .pinyin, ascending: true)
        try driver.send("sortChanged", Data(#"{"sort":{"field":"pinyin","ascending":true}}"#.utf8))
        #expect(sorts == [byPinyin])
        #expect(library.state.sort == byPinyin)

        try driver.send("dictionaryTapped", Data(#"{"word":0}"#.utf8))
        #expect(driver.back())
        #expect(library.state.dictionary == nil)
        #expect(!driver.back())
    }

    private static func probe(_ name: String) -> ScreenDriver {
        ScreenDriver(
            name: name, actions: ["appeared", "disappeared"], state: { name }, summary: { $0 },
            send: { (_: Lifecycle) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
        )
    }

    private enum Lifecycle: Decodable {
        case appeared, disappeared
    }

    @Test("words are listed alphabetically and filtered by the search")
    func searching() async {
        let (library, _) = await makeLibrary()
        #expect(library.state.words.first?.english == "")
        #expect(library.state.words.dropFirst().first?.english == "book")

        library.send(.searchChanged("sh"))
        #expect(library.state.words.map(\.english) == ["book", "water", "mobile phone"].sorted())
    }

    @Test("the list is sorted once, kept while the search is typed, and sorted again when the words or the sort change")
    func sortedOnce() async {
        let (library, _) = await makeLibrary()
        let sorted = library.state.listed
        library.send(.searchChanged("w"))
        library.send(.searchChanged("wa"))
        #expect(library.state.listed == sorted)
        #expect(library.state.words.map(\.english) == ["water"])

        library.send(.sortChanged(WordSort(field: .mistakes, ascending: false)))
        #expect(library.state.listed.map(\.english).prefix(3) == ["mobile phone", "book", "tea"])
        #expect(library.state.words.map(\.english) == ["water"])

        library.send(.deleteTapped([Fixtures.phone.id]))
        #expect(library.state.listed.map(\.english).prefix(2) == ["book", "tea"])
    }

    @Test("the list is searched by pinyin ignoring tones, by English, and by Hanzi, as the dictionary is", arguments: [
        ("shui", ["water"]), ("shuǐ", ["water"]), ("shui3", ["water"]), ("shou ji", ["mobile phone"]),
        ("cha", ["tea"]), ("WATER", ["water"]), ("手机", ["mobile phone"]),
    ])
    func searchingLikeTheDictionary(query: String, found: [String]) async {
        let (library, _) = await makeLibrary()
        library.send(.searchChanged(query))
        #expect(library.state.words.map(\.english) == found)
    }

    /// Kitchen holds Drinks, with water and tea, and Pantry, which holds Snacks, sharing tea
    /// and adding green. Book is in no deck here.
    private enum Kitchen {
        static let kitchen = FolderSummary(id: UUID(), name: "Kitchen", createdAt: .now)
        static let pantry = FolderSummary(id: UUID(), name: "Pantry", createdAt: .now, parentID: kitchen.id)
        static let empty = FolderSummary(id: UUID(), name: "Empty", createdAt: .now)
        static let drinks = DeckSummary(
            id: UUID(), name: "Drinks", createdAt: .now, wordIDs: [Fixtures.water.id, Fixtures.tea.id], folderID: kitchen.id
        )
        static let snacks = DeckSummary(
            id: UUID(), name: "Snacks", createdAt: .now, wordIDs: [Fixtures.tea.id, Fixtures.green.id], folderID: pantry.id
        )
        static let vocabulary = Vocabulary(
            words: Fixtures.words, decks: [drinks, snacks], folders: [kitchen, pantry, empty]
        )
    }

    private func makeFolderList(_ folderID: UUID, repository: FakeVocabularyRepository) -> WordLibraryViewModel {
        WordLibraryViewModel(
            folderID: folderID,
            vocabulary: Kitchen.vocabulary,
            sort: .default,
            searchText: "",
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            setLearnt: SetWordLearntUseCase(repository: repository)
        )
    }

    @Test("a folder lists every word in its decks and its folders' decks, once each, as it appears and before its subscription delivers")
    func folderWords() {
        let list = makeFolderList(Kitchen.kitchen.id, repository: FakeVocabularyRepository(Kitchen.vocabulary))
        #expect(list.state.listed.isEmpty)
        list.send(.appeared)
        #expect(list.state.words.map(\.english) == ["green", "tea", "water"])
        #expect(list.state.hasWords)

        let pantry = makeFolderList(Kitchen.pantry.id, repository: FakeVocabularyRepository(Kitchen.vocabulary))
        pantry.send(.appeared)
        #expect(pantry.state.words.map(\.english) == ["green", "tea"])
    }

    @Test("the count reads as all of them, or how many the search finds of them")
    func counting() async {
        let (library, _) = await makeLibrary()
        #expect(library.state.count == "6 words")
        library.send(.searchChanged("sh"))
        #expect(library.state.count == "3 of 6 words")
    }

    @Test("a folder's list is sorted and searched as the list of all words is, and never shows a word outside it")
    func folderSortAndSearch() {
        let list = makeFolderList(Kitchen.kitchen.id, repository: FakeVocabularyRepository(Kitchen.vocabulary))
        list.send(.appeared)
        list.send(.sortChanged(WordSort(field: .mistakes, ascending: false)))
        #expect(list.state.words.map(\.english) == ["tea", "green", "water"])

        // Book, shū, is in no deck of Kitchen's.
        list.send(.sortChanged(.default))
        list.send(.searchChanged("shu"))
        #expect(list.state.words.map(\.english) == ["water"])
    }

    @Test("a folder with no words in its decks has none, and nor does one that is gone")
    func folderWithoutWords() async {
        let empty = makeFolderList(Kitchen.empty.id, repository: FakeVocabularyRepository(Kitchen.vocabulary))
        #expect(!empty.state.hasWords)
        #expect(empty.state.words.isEmpty)

        let repository = FakeVocabularyRepository(Kitchen.vocabulary)
        let list = makeFolderList(Kitchen.kitchen.id, repository: repository)
        list.send(.appeared)
        await repository.replace(Vocabulary(words: Fixtures.words, decks: [], folders: []))
        #expect(await waitUntil { !list.state.hasWords })
        #expect(list.state.words.isEmpty)
    }

    @Test("the editor opens on the chosen word")
    func editor() async {
        let (library, _) = await makeLibrary()
        library.send(.editTapped(Fixtures.tea.id))
        #expect(library.state.editor == .edit(Fixtures.tea))

        library.send(.editorDismissed)
        #expect(library.state.editor == nil)
    }

    @Test("a word is marked learnt and unmarked from the list")
    func learnt() async {
        let (library, _) = await makeLibrary()
        library.send(.learntToggled(Fixtures.tea.id))
        #expect(await waitUntil { library.state.vocabulary.words.first { $0.id == Fixtures.tea.id }?.isLearnt == true })
        library.send(.learntToggled(Fixtures.tea.id))
        #expect(await waitUntil { library.state.vocabulary.words.first { $0.id == Fixtures.tea.id }?.isLearnt == false })
        #expect(await repository.writes == ["setLearnt true", "setLearnt false"])
    }

    @Test("the dictionary opens on a word's Hanzi and its reading")
    func dictionary() async {
        let (library, _) = await makeLibrary()
        library.send(.dictionaryTapped(Fixtures.water.id))
        #expect(library.state.dictionary == DictionaryHeadword(hanzi: "水", pinyin: "shuǐ"))

        library.send(.dictionaryDismissed)
        #expect(library.state.dictionary == nil)
    }

    @Test("deleting removes the word at once and from the store")
    func deleting() async {
        let (library, _) = await makeLibrary()
        library.send(.deleteTapped([Fixtures.tea.id]))

        #expect(!library.state.words.contains(Fixtures.tea))
        #expect(await waitUntil { await repository.writes == ["deleteWords 1"] })
    }

    @Test("a failed delete puts the word back and says why")
    func failedDelete() async {
        let (library, log) = await makeLibrary()
        await repository.failWrites()

        library.send(.deleteTapped([Fixtures.tea.id]))

        #expect(await log.contains(.showError(.deleteWordsFailed(FakeVocabularyRepository.failure))))
        #expect(library.state.words.contains(Fixtures.tea))
    }
}
