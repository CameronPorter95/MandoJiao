import Foundation
import Observation

@MainActor
@Observable
final class WordEditorViewModel {
    private(set) var state: WordEditorState

    private let effectChannel = EffectChannel<WordEditorEffect>()
    private let saveWord: SaveWordUseCase
    private let deleteWords: DeleteWordsUseCase

    init(word: Word?, saveWord: SaveWordUseCase, deleteWords: DeleteWordsUseCase) {
        state = WordEditorState(
            wordID: word?.id,
            draft: WordDraft(english: word?.english ?? "", hanzi: word?.hanzi ?? "", pinyin: word?.pinyin ?? "")
        )
        self.saveWord = saveWord
        self.deleteWords = deleteWords
    }

    func effects() -> AsyncStream<WordEditorEffect> { effectChannel.stream() }

    func send(_ action: WordEditorAction) {
        switch action {
        case .englishChanged(let text):
            state.draft.english = text

        case .hanziChanged(let text):
            state.draft.hanzi = text

        case .pinyinChanged(let text):
            state.draft.pinyin = text

        case .saveTapped:
            guard state.canSave else { return }
            let id = state.wordID
            let draft = state.draft
            write(failure: VocabularyError.saveWordFailed) { [saveWord] in
                try await saveWord(id: id, draft: draft)
            }

        case .deleteTapped:
            guard let id = state.wordID else { return }
            write(failure: VocabularyError.deleteWordsFailed) { [deleteWords] in
                try await deleteWords(ids: [id])
            }

        case .cancelTapped:
            effectChannel.send(.dismiss)
        }
    }

    /// Stays open on failure, so nothing typed is lost.
    private func write(
        failure: @escaping (VocabularyDomainError) -> VocabularyError,
        _ work: @escaping () async throws -> Void
    ) {
        Task {
            let outcome = await VocabularyError.performing(work, failure: failure) {
                effectChannel.send(.showError($0))
            }
            if outcome == .succeeded { effectChannel.send(.dismiss) }
        }
    }
}
