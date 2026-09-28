import Foundation
import Testing
import CoreDomain
@testable import VocabularyDomain
@testable import VocabularyData

@Suite("Library layout")
nonisolated struct LibraryLayoutTests {
    private let defaults = UserDefaults(suiteName: "LibraryLayoutTests-\(UUID().uuidString)")!
    private let a = UUID()
    private let b = UUID()

    @Test("unfolding in one scope leaves every other scope as it was")
    func scopes() {
        let layout = LibraryLayout()
            .settingExpanded(a, true, in: .tree)
            .settingExpanded(a, true, in: .folder(b))
            .settingExpanded(a, false, in: .tree)

        #expect(layout.expanded(in: .tree).isEmpty)
        #expect(layout.expanded(in: .folder(b)) == [a])
        #expect(layout.expanded(in: .folder(a)).isEmpty)
    }

    @Test("each section of each folder folds on its own")
    func sections() {
        let layout = LibraryLayout()
            .toggling(.folders, in: a)
            .toggling(.decks, in: b)
            .toggling(.folders, in: b)
            .toggling(.decks, in: b)

        #expect(layout.isFolded(.folders, in: a))
        #expect(!layout.isFolded(.decks, in: a))
        #expect(layout.isFolded(.folders, in: b))
        #expect(!layout.isFolded(.decks, in: b))
    }

    @Test("each folder keeps its own deck sort, and one never set is the default")
    func sorts() {
        let byTitle = DeckSort(field: .title, ascending: true)
        let layout = LibraryLayout().settingDeckSort(byTitle, in: a)

        #expect(layout.deckSort(in: a) == byTitle)
        #expect(layout.deckSort(in: b) == .default)
        #expect(layout.settingDeckSort(.default, in: a) == LibraryLayout())
    }

    @Test("the word list keeps its sort, and a layout saved before it could be sorted still loads")
    func wordSort() throws {
        let byMistakes = WordSort(field: .mistakes, ascending: false)
        let layout = LibraryLayout().settingDeckSort(DeckSort(field: .size, ascending: true), in: a).settingWordSort(byMistakes)
        #expect(layout.wordSort == byMistakes)
        #expect(layout.settingWordSort(.default).wordSort == .default)

        let repository = LibraryLayoutRepositoryImpl(defaults: defaults)
        repository.save(layout)
        #expect(LibraryLayoutRepositoryImpl(defaults: defaults).layout() == layout)

        // As saved before words had a sort: the deck sort survives, the word sort is the default.
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(layout)) as! [String: Any]
        old.removeValue(forKey: "savedWordSort")
        let decoded = try JSONDecoder().decode(LibraryLayout.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(decoded.wordSort == .default)
        #expect(decoded.deckSort(in: a) == DeckSort(field: .size, ascending: true))
    }

    @Test("the layout survives a relaunch, and a store with none starts folded")
    func persistence() {
        let repository = LibraryLayoutRepositoryImpl(defaults: defaults)
        #expect(repository.layout() == LibraryLayout())

        let layout = LibraryLayout()
            .settingExpanded(a, true, in: .folder(b))
            .toggling(.decks, in: a)
            .settingDeckSort(DeckSort(field: .size, ascending: true), in: b)
        repository.save(layout)
        #expect(LibraryLayoutRepositoryImpl(defaults: defaults).layout() == layout)
    }

    @Test("a saved layout that no longer reads starts folded instead of failing")
    func unreadable() {
        defaults.set(Data("not json".utf8), forKey: Preferences.Key.libraryLayout)
        #expect(LibraryLayoutRepositoryImpl(defaults: defaults).layout() == LibraryLayout())
    }
}
