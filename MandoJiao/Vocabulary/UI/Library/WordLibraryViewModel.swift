import Foundation
import Observation

@MainActor
@Observable
final class WordLibraryViewModel {
    private(set) var state = WordLibraryState()

    private let effectChannel = EffectChannel<WordLibraryEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let deleteWords: DeleteWordsUseCase
    private var observation: Task<Void, Never>?

    init(observeVocabulary: ObserveVocabularyUseCase, deleteWords: DeleteWordsUseCase) {
        self.observeVocabulary = observeVocabulary
        self.deleteWords = deleteWords
    }

    func effects() -> AsyncStream<WordLibraryEffect> { effectChannel.stream() }

    func send(_ action: WordLibraryAction) {
        switch action {
        case .appeared:
            guard observation == nil else { return }
            let stream = observeVocabulary()
            observation = Task { [weak self] in
                for await vocabulary in stream {
                    self?.state.vocabulary = vocabulary
                }
            }

        case .disappeared:
            observation?.cancel()
            observation = nil

        case .searchChanged(let text):
            state.searchText = text

        case .addTapped:
            state.editor = .new

        case .editTapped(let id):
            guard let word = state.vocabulary.words.first(where: { $0.id == id }) else { return }
            state.editor = .edit(word)

        case .editorDismissed:
            state.editor = nil

        case .deleteTapped(let ids):
            let previous = state.vocabulary
            state.vocabulary.words.removeAll { ids.contains($0.id) }
            Task {
                let outcome = await VocabularyError.performing(
                    { [deleteWords] in try await deleteWords(ids: ids) },
                    failure: VocabularyError.deleteWordsFailed,
                    show: { effectChannel.send(.showError($0)) }
                )
                if outcome == .failed { state.vocabulary = previous }
            }
        }
    }
}
