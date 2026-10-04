import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class WordLibraryViewModel {
    private(set) var state: WordLibraryState

    private let effectChannel = EffectChannel<WordLibraryEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let deleteWords: DeleteWordsUseCase
    private var observation: Task<Void, Never>?

    /// All words without a `folderID`, or the words in the decks beneath that folder.
    /// `vocabulary` is the library's latest snapshot, so a folder's list shows its words
    /// before its own subscription delivers.
    public init(
        folderID: UUID?,
        vocabulary: Vocabulary,
        observeVocabulary: ObserveVocabularyUseCase,
        deleteWords: DeleteWordsUseCase
    ) {
        state = WordLibraryState(folderID: folderID, vocabulary: vocabulary)
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
            state.editor = .new(WordDraft())

        case .editTapped(let id):
            guard let word = state.vocabulary.words.first(where: { $0.id == id }) else { return }
            state.editor = .edit(word)

        case .editorDismissed:
            state.editor = nil

        case .dictionaryTapped(let id):
            guard let word = state.vocabulary.words.first(where: { $0.id == id }), !word.hanzi.isEmpty else { return }
            state.dictionary = DictionaryHeadword(hanzi: word.hanzi, pinyin: word.pinyin.isEmpty ? nil : word.pinyin)

        case .dictionaryDismissed:
            state.dictionary = nil

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
