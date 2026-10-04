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
    private let observeVocabulary: ObserveVocabularyUseCase
    private let searchDelay: Duration
    private var searching: Task<Void, Never>?
    private var observation: Task<Void, Never>?

    /// `searchDelay` waits for typing to pause, since every search reads the whole dictionary.
    public init(
        searchDictionary: SearchDictionaryUseCase,
        observeVocabulary: ObserveVocabularyUseCase,
        searchDelay: Duration = .milliseconds(250)
    ) {
        self.searchDictionary = searchDictionary
        self.observeVocabulary = observeVocabulary
        self.searchDelay = searchDelay
    }

    func send(_ action: DictionarySearchAction) {
        switch action {
        case .appeared:
            // Live, so a result shows as saved as soon as the editor saves it.
            guard observation == nil else { return }
            let stream = observeVocabulary()
            observation = Task { [weak self] in
                for await vocabulary in stream {
                    self?.state.words = vocabulary.words
                }
            }

        case .disappeared:
            observation?.cancel()
            observation = nil

        case .vocabularyTapped(let result):
            guard let vocabulary = state.vocabulary(for: result) else { return }
            state.editor = vocabulary.editor(for: result.entry)

        case .editorDismissed:
            state.editor = nil

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
