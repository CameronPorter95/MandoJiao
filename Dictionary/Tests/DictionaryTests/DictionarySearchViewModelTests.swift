import Foundation
import Testing
import CoreDomain
import CoreTestSupport
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
