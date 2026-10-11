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
    private var searching: Task<Void, Never>?
    private var observation: Task<Void, Never>?

    public init(searchDictionary: SearchDictionaryUseCase, observeSaved: ObserveSavedReadingsUseCase) {
        self.searchDictionary = searchDictionary
        self.observeSaved = observeSaved
    }

    func send(_ action: DictionarySearchAction) {
        switch action {
        case .appeared:
            // Built off the main actor, once, however often the tab appears.
            Task { [searchDictionary] in await searchDictionary.prepare() }
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

        case .opened(let headword):
            state.path.append(headword)

        case .pathChanged(let path):
            state.path = path

        case .queryChanged(let query):
            // The field sets the same text again, such as on return.
            guard query != state.query else { return }
            state.query = query
            searching?.cancel()
            guard !state.isBlank else {
                state.results = .none
                state.isSearching = false
                return
            }
            // No pause for typing to stop: a search takes milliseconds once the dictionary is
            // indexed, and a later keystroke cancels this one.
            state.isSearching = true
            searching = Task { [searchDictionary] in
                do {
                    let found = try await searchDictionary(query)
                    try Task.checkCancellation()
                    state.results = .found(found)
                } catch is CancellationError {
                    // Superseded by later typing, not a failure.
                    return
                } catch {
                    let domainError = error as? DictionaryDomainError ?? .unexpected(model: DomainErrorModel(error))
                    DictionaryError.searchFailed(domainError).log()
                    state.results = .failed
                }
                state.isSearching = false
            }
        }
    }
}
