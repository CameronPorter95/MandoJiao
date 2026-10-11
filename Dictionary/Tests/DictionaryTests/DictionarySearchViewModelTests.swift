import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import CoreUI
import DictionaryTestSupport
@testable import DictionaryDomain
@testable import DictionaryUI

@Suite("Dictionary search")
@MainActor
struct DictionarySearchViewModelTests {
    private let dictionary = FakeDictionaryRepository()

    private let vocabulary = FakeSavedReadingsRepository()

    private func makeSearch(delay: Duration = .zero) -> DictionarySearchViewModel {
        DictionarySearchViewModel(
            searchDictionary: SearchDictionaryUseCase(repository: dictionary),
            observeSaved: ObserveSavedReadingsUseCase(repository: vocabulary),
            searchDelay: delay
        )
    }

    private func found(_ search: DictionarySearchViewModel, _ query: String) async -> [DictionarySearchResult] {
        search.send(.queryChanged(query))
        guard await waitUntil({ search.state.results != .searching }), case .found(let results) = search.state.results
        else { return [] }
        return results
    }

    @Test("driven, the editor a result opens is in front, over any pushed page, and back closes it first")
    func drivenEditor() async throws {
        let search = makeSearch()
        search.send(.appeared)
        #expect(await waitUntil { search.state.saved != nil })
        var dismiss: (() -> Void)?
        let driver = search.driver(
            page: { headword, _ in editorProbe(.add(DictionaryEntry(simplified: "page \(headword.hanzi)", traditional: "", pinyin: "", isPreferred: true, senses: []))) },
            editor: { edit, dismissed in
                dismiss = dismissed
                return editorProbe(edit)
            }
        )
        try driver.send("queryChanged", Data(#"{"query":"喝"}"#.utf8))
        #expect(await waitUntil { !driver.isBusy() })

        try driver.send("opened", Data(#"{"result":0}"#.utf8))
        // Only the page in front lists itself, so the search names the way to it.
        #expect(driver.summary().contains("pages: \(search.state.path.map(\.hanzi).joined(separator: " › "))"))
        try driver.send("vocabularyTapped", Data(#"{"result":0}"#.utf8))
        let edit = try #require(search.state.editor)
        #expect(driver.front()?.name == "word editor \(edit.id)")

        // The editor closes before the page beneath it is popped.
        #expect(driver.back())
        #expect(search.state.editor == nil)
        #expect(search.state.path.count == 1)

        try driver.send("vocabularyTapped", Data(#"{"result":0}"#.utf8))
        dismiss?()
        #expect(search.state.editor == nil)
    }

    @Test("driven, a search is typed and a result picked by its place in the list")
    func driven() async throws {
        let search = makeSearch()
        search.send(.appeared)
        #expect(await waitUntil { search.state.saved != nil })
        let driver = search.driver()

        try driver.send("queryChanged", Data(#"{"query":"喝"}"#.utf8))
        #expect(await waitUntil { driver.summary().contains("results: 2  0. 喝 hē to drink | 1. 喝 hè") })

        try driver.send("vocabularyTapped", Data(#"{"result":5}"#.utf8))
        #expect(search.state.editor == nil)
        try driver.send("vocabularyTapped", Data(#"{"result":0}"#.utf8))
        #expect(search.state.editor != nil)

        let arguments = ["queryChanged": #"{"query":"银"}"#, "vocabularyTapped": #"{"result":0}"#, "opened": #"{"result":0}"#]
        for name in driver.actions {
            #expect(throws: Never.self) { try driver.send(name, arguments[name].map { Data($0.utf8) }) }
        }
    }

    @Test("driven, a result's page is pushed, a character's over it, and back pops each")
    func drivenStack() async throws {
        let lookUp = LookUpDictionaryUseCase(repository: dictionary)
        let search = makeSearch()
        let driver = search.driver { headword, open in
            DictionaryPageViewModel(headword: headword, lookUpDictionary: lookUp, observeSaved: nil).driver(open: open)
        }
        try driver.send("appeared", nil)
        #expect(driver.front() == nil)

        try driver.send("queryChanged", Data(#"{"query":"银行"}"#.utf8))
        #expect(await waitUntil { !driver.isBusy() })
        try driver.send("opened", Data(#"{"result":0}"#.utf8))
        #expect(search.state.path == [DictionaryHeadword(hanzi: "银行", pinyin: "yínháng")])

        let page = try #require(driver.front())
        #expect(await waitUntil { !page.isBusy() })
        try page.send("characterOpened", Data(#"{"character":1}"#.utf8))
        #expect(search.state.path.map(\.hanzi) == ["银行", "行"])
        #expect(await waitUntil { driver.front()?.summary().hasPrefix("page  行  readings: ") == true })

        #expect(driver.back())
        #expect(driver.front()?.summary().hasPrefix("page  银行") == true)
        #expect(driver.back())
        #expect(driver.front() == nil)
        #expect(!driver.back())
    }

    @Test("a link the view pushes reaches the stack the driver reads")
    func linksPushThroughThePath() {
        let search = makeSearch()
        // What the bound NavigationStack sends when a NavigationLink(value:) is tapped.
        search.send(.pathChanged([DictionaryHeadword(hanzi: "喝", pinyin: "hē")]))
        #expect(search.state.path == [DictionaryHeadword(hanzi: "喝", pinyin: "hē")])
    }

    @Test("appearing prepares the search before anything is typed, so the first query does not build it")
    func preparedOnAppearing() async {
        let search = makeSearch()
        search.send(.appeared)
        #expect(await waitUntil { await dictionary.preparations == 1 })
        #expect(await dictionary.searches.isEmpty)
    }

    @Test("typing searches once typing pauses, for only the last query")
    func debounced() async {
        let search = makeSearch(delay: .milliseconds(50))
        search.send(.queryChanged("银"))
        search.send(.queryChanged("银行"))
        #expect(search.state.results == .searching)

        #expect(await waitUntil { search.state.results != .searching })
        #expect(search.state.results == .found([DictionarySearchResult(entry: FakeDictionaryRepository.words[2])]))
        #expect(await dictionary.searches == ["银行"])
    }

    @Test("the same text set again, as the field does on return, does not search again")
    func unchanged() async {
        let search = makeSearch()
        search.send(.queryChanged("喝"))
        #expect(await waitUntil { search.state.results != .searching })
        let found = search.state.results

        search.send(.queryChanged("喝"))
        #expect(search.state.results == found)
        await settle()
        #expect(await dictionary.searches == ["喝"])
    }

    @Test("clearing the query clears the results without searching")
    func blank() async {
        let search = makeSearch()
        search.send(.queryChanged("喝"))
        #expect(await waitUntil { search.state.results != .searching })

        search.send(.queryChanged("  "))
        #expect(search.state.results == .none)
        await settle()
        #expect(await dictionary.searches == ["喝"])
    }

    @Test("nothing found is told apart from a failed search, which shows no alert")
    func emptyAndFailed() async {
        let search = makeSearch()
        search.send(.queryChanged("zzz"))
        #expect(await waitUntil { search.state.results == .found([]) })

        await dictionary.failLookups()
        search.send(.queryChanged("喝"))
        #expect(await waitUntil { search.state.results == .failed })
    }

    @Test("a result shows whether its reading is saved, however the word's pinyin was typed")
    func savedResults() async throws {
        let hang = SavedReading(id: UUID(), hanzi: "行", pinyin: "hang2")
        await vocabulary.replace([hang])
        let search = makeSearch()
        #expect(search.state.saved == nil)
        search.send(.appeared)
        #expect(await waitUntil { search.state.saved != nil })

        let results = await found(search, "行").filter { $0.simplified == "行" }
        #expect(results.map(\.pinyin) == ["xíng", "háng"])
        #expect(results.map { search.state.vocabulary(for: $0) } == [.absent, .saved(hang)])
    }

    @Test("a result not saved is added, and a saved one opens its word")
    func vocabularyFromResults() async throws {
        let hang = SavedReading(id: UUID(), hanzi: "行", pinyin: "háng")
        await vocabulary.replace([hang])
        let search = makeSearch()
        search.send(.appeared)
        #expect(await waitUntil { search.state.saved != nil })
        let results = await found(search, "行").filter { $0.simplified == "行" }

        search.send(.vocabularyTapped(results[0]))
        #expect(search.state.editor == .add(results[0].entry))
        search.send(.editorDismissed)
        #expect(search.state.editor == nil)
        search.send(.vocabularyTapped(results[1]))
        #expect(search.state.editor == .open(hang))
    }

    @Test("a result shows as saved as soon as it is saved, until the list is left")
    func savedResultsLive() async throws {
        let search = makeSearch()
        search.send(.appeared)
        #expect(await waitUntil { search.state.saved != nil })
        let he = try #require(await found(search, "喝").first)
        #expect(search.state.vocabulary(for: he) == .absent)

        await vocabulary.save(hanzi: "喝", pinyin: "hē")
        #expect(await waitUntil { search.state.vocabulary(for: he)?.isSaved == true })

        search.send(.disappeared)
        await vocabulary.replace([])
        await settle()
        #expect(search.state.vocabulary(for: he)?.isSaved == true)
    }

    @Test("nothing can be added before the saved words are known, so a saved reading is not added twice")
    func vocabularyUnknown() async throws {
        let search = makeSearch()
        let results = await found(search, "喝")
        #expect(search.state.vocabulary(for: results[0]) == nil)
        search.send(.vocabularyTapped(results[0]))
        #expect(search.state.editor == nil)
    }
}

/// A stand-in for the library's word editor, which the dictionary cannot see.
@MainActor
private func editorProbe(_ edit: ReadingEdit) -> ScreenDriver {
    ScreenDriver(
        name: "word editor \(edit.id)", actions: [], state: { 0 }, summary: { _ in "" },
        send: { (_: Int) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
    )
}
