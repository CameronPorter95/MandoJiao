import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyUI

@Suite("Dictionary search")
@MainActor
struct DictionarySearchViewModelTests {
    private let dictionary = FakeDictionaryRepository()

    private func makeSearch(delay: Duration = .zero) -> DictionarySearchViewModel {
        DictionarySearchViewModel(searchDictionary: SearchDictionaryUseCase(repository: dictionary), searchDelay: delay)
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
}
