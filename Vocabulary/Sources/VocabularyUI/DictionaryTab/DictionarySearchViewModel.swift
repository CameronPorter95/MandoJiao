import CoreDomain
import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class DictionarySearchViewModel {
    private(set) var state = DictionarySearchState()

    private let searchDictionary: SearchDictionaryUseCase
    private let searchDelay: Duration
    private var searching: Task<Void, Never>?

    /// `searchDelay` waits for typing to pause, since every search reads the whole dictionary.
    public init(searchDictionary: SearchDictionaryUseCase, searchDelay: Duration = .milliseconds(250)) {
        self.searchDictionary = searchDictionary
        self.searchDelay = searchDelay
    }

    func send(_ action: DictionarySearchAction) {
        switch action {
        case .queryChanged(let query):
            // The field sets the same text again, such as on return.
            guard query != state.query else { return }
            state.query = query
            searching?.cancel()
            guard !state.isBlank else {
                state.results = .none
                return
            }
            state.results = .searching
            searching = Task { [searchDictionary, searchDelay] in
                do {
                    try await Task.sleep(for: searchDelay)
                    let found = try await searchDictionary(query)
                    try Task.checkCancellation()
                    state.results = .found(found)
                } catch is CancellationError {
                    // Superseded by later typing, not a failure.
                } catch {
                    let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                    VocabularyError.searchDictionaryFailed(domainError).log()
                    state.results = .failed
                }
            }
        }
    }
}
