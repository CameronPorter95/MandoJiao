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

    @Test("a section folds and unfolds per folder")
    func sections() {
        let layout = LibraryLayout().togglingSection(of: a).togglingSection(of: b).togglingSection(of: b)
        #expect(layout.foldedSections == [a])
    }

    @Test("the layout survives a relaunch, and a store with none starts folded")
    func persistence() {
        let repository = LibraryLayoutRepositoryImpl(defaults: defaults)
        #expect(repository.layout() == LibraryLayout())

        let layout = LibraryLayout().settingExpanded(a, true, in: .folder(b)).togglingSection(of: a)
        repository.save(layout)
        #expect(LibraryLayoutRepositoryImpl(defaults: defaults).layout() == layout)
    }

    @Test("a saved layout that no longer reads starts folded instead of failing")
    func unreadable() {
        defaults.set(Data("not json".utf8), forKey: Preferences.Key.libraryLayout)
        #expect(LibraryLayoutRepositoryImpl(defaults: defaults).layout() == LibraryLayout())
    }
}
