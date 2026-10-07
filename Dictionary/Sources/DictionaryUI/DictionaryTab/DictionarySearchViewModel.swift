import CoreDomain
import CoreUI
import DictionaryDomain
import Foundation
import Observation

@MainActor
@Observable
public final class DictionarySearchViewModel {
    private(set) var state = DictionarySearchState()

    private let searchDictionary: SearchDictionaryUseCase
    private let observeSaved: ObserveSavedReadingsUseCase
    private let searchDelay: Duration
    private var searching: Task<Void, Never>?
    private var observation: Task<Void, Never>?

    /// `searchDelay` waits for typing to pause, since every search reads the whole dictionary.
    public init(
        searchDictionary: SearchDictionaryUseCase,
        observeSaved: ObserveSavedReadingsUseCase,
        searchDelay: Duration = .milliseconds(250)
    ) {
        self.searchDictionary = searchDictionary
        self.observeSaved = observeSaved
        self.searchDelay = searchDelay
    }

    func send(_ action: DictionarySearchAction) {
        switch action {
        case .appeared:
            // Live, so a result shows as saved as soon as the editor saves it.
            guard observation == nil else { return }
            let stream = observeSaved()
            observation = Task { [weak self] in
                for await saved in stream {
                    self?.state.saved = saved
                }
            }

        case .disappeared:
            observation?.cancel()
            observation = nil

        case .vocabularyTapped(let result):
            guard let vocabulary = state.vocabulary(for: result) else { return }
            state.editor = vocabulary.edit(for: result.entry)

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
                    let domainError = error as? DictionaryDomainError ?? .unexpected(model: DomainErrorModel(error))
                    DictionaryError.searchFailed(domainError).log()
                    state.results = .failed
                }
            }
        }
    }
}
