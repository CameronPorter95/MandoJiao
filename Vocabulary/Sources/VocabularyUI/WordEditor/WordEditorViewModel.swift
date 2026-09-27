import CoreDomain
import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class WordEditorViewModel {
    private(set) var state: WordEditorState

    private let effectChannel = EffectChannel<WordEditorEffect>()
    private let saveWord: SaveWordUseCase
    private let deleteWords: DeleteWordsUseCase
    private let suggestWord: SuggestWordUseCase
    private let suggestionDelay: Duration
    private var suggestionTask: Task<Void, Never>?

    /// `suggestionDelay` waits for typing to pause before looking the Hanzi up.
    public init(
        word: Word?,
        saveWord: SaveWordUseCase,
        deleteWords: DeleteWordsUseCase,
        suggestWord: SuggestWordUseCase,
        suggestionDelay: Duration = .milliseconds(250)
    ) {
        state = WordEditorState(
            wordID: word?.id,
            draft: WordDraft(english: word?.english ?? "", hanzi: word?.hanzi ?? "", pinyin: word?.pinyin ?? "")
        )
        self.saveWord = saveWord
        self.deleteWords = deleteWords
        self.suggestWord = suggestWord
        self.suggestionDelay = suggestionDelay
    }

    func effects() -> AsyncStream<WordEditorEffect> { effectChannel.stream() }

    func send(_ action: WordEditorAction) {
        switch action {
        case .appeared:
            suggest()

        case .englishChanged(let text):
            state.draft.english = text

        case .hanziChanged(let text):
            state.draft.hanzi = text
            suggest()

        case .pinyinChanged(let text):
            state.draft.pinyin = text

        case .saveTapped:
            guard state.canSave else { return }
            let id = state.wordID
            let draft = state.submission
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

    private func suggest() {
        suggestionTask?.cancel()
        let hanzi = state.draft.hanzi
        suggestionTask = Task { [suggestWord, suggestionDelay] in
            do {
                try await Task.sleep(for: suggestionDelay)
                let suggestion = try await suggestWord(hanzi: hanzi)
                guard !Task.isCancelled else { return }
                state.suggestion = suggestion
            } catch is CancellationError {
                // Superseded by later typing, not a failure.
            } catch {
                // Logged but not shown: an alert while typing would cost more than a missing hint.
                let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                VocabularyError.suggestWordFailed(domainError).log()
            }
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
