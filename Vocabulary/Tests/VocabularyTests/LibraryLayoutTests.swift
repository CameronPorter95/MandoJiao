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
