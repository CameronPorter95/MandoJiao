import CoreDomain
import CoreUI
import DictionaryDomain
import Foundation
import LibraryDomain
import Observation

@MainActor
@Observable
public final class WordEditorViewModel {
    private(set) var state: WordEditorState

    private let effectChannel = EffectChannel<WordEditorEffect>()
    private let saveWord: SaveWordUseCase
    private let deleteWords: DeleteWordsUseCase
    private let setLearnt: SetWordLearntUseCase
    private let suggestWord: SuggestWordUseCase
    private let lookUpDictionary: LookUpDictionaryUseCase
    private let observeVocabulary: ObserveVocabularyUseCase
    private let suggestionDelay: Duration
    private var suggestionTask: Task<Void, Never>?
    private var observation: Task<Void, Never>?

    public nonisolated static let defaultSuggestionDelay: Duration = .milliseconds(250)

    /// `suggestionDelay` waits for typing to pause before looking the Hanzi up.
    public init(
        target: WordEditorTarget,
        saveWord: SaveWordUseCase,
        deleteWords: DeleteWordsUseCase,
        setLearnt: SetWordLearntUseCase,
        suggestWord: SuggestWordUseCase,
        lookUpDictionary: LookUpDictionaryUseCase,
        observeVocabulary: ObserveVocabularyUseCase,
        suggestionDelay: Duration = defaultSuggestionDelay
    ) {
        state = switch target {
        case .new(let draft):
            WordEditorState(wordID: nil, draft: draft)
        case .edit(let word):
            WordEditorState(word: word)
        case .saved(let id):
            WordEditorState(loading: id)
        }
        self.saveWord = saveWord
        self.deleteWords = deleteWords
        self.setLearnt = setLearnt
        self.suggestWord = suggestWord
        self.lookUpDictionary = lookUpDictionary
        self.observeVocabulary = observeVocabulary
        self.suggestionDelay = suggestionDelay
    }

    func effects() -> AsyncStream<WordEditorEffect> { effectChannel.stream() }

    func send(_ action: WordEditorAction) {
        switch action {
        case .appeared:
            suggest()
            observe()

        case .disappeared:
            observation?.cancel()
            observation = nil

        case .hanziChanged(let text):
            state.draft.hanzi = text
            suggest()

        case .pinyinChanged(let text):
            state.draft.pinyin = text

        case .senseToggled(let sense):
            state.editMeanings { meanings in
                if let index = meanings.firstIndex(of: sense) {
                    meanings.remove(at: index)
                } else {
                    meanings.removeAll(where: Self.isBlank)
                    meanings.append(sense)
                }
            }

        case .meaningAdded(let text):
            let meaning = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !meaning.isEmpty, !state.meanings.contains(where: { $0.caseInsensitiveCompare(meaning) == .orderedSame })
            else { return }
            state.editMeanings { meanings in
                meanings.removeAll(where: Self.isBlank)
                meanings.append(meaning)
            }

        case .meaningEdited(let index, let text):
            // Kept as typed, even blank, so the field is not taken away mid-edit. Saving trims.
            state.editMeanings { meanings in
                if meanings.indices.contains(index) {
                    meanings[index] = text
                } else if index == meanings.count {
                    meanings.append(text)
                }
            }

        case .meaningsMoved(let from, let to):
            state.editMeanings { $0.move(fromOffsets: from, toOffset: to) }

        case .meaningsRemoved(let offsets):
            state.editMeanings { $0.remove(atOffsets: offsets) }

        case .sensesTapped:
            state.isChoosingSenses = !state.tickableEntries.isEmpty

        case .sensesDismissed:
            state.isChoosingSenses = false

        case .dictionaryTapped:
            state.dictionary = state.dictionaryHeadword

        case .dictionaryDismissed:
            state.dictionary = nil

        case .deckChosen(let id):
            state.deckID = id

        case .deckSectionToggled(let id):
            if state.foldedDeckSections.remove(id) == nil {
                state.foldedDeckSections.insert(id)
            }

        case .saveTapped:
            guard state.canSave else { return }
            let id = state.wordID
            let draft = state.submission
            let deckID = state.chosenDeckID
            let learnt: Bool? = state.isLearnt == state.wasLearnt ? nil : state.isLearnt
            write(failure: VocabularyError.saveWordFailed) { [saveWord, setLearnt] in
                try await saveWord(id: id, draft: draft, deckID: deckID)
                if let id, let learnt { try await setLearnt(wordID: id, isLearnt: learnt) }
            }

        case .learntToggled(let isLearnt):
            state.isLearnt = isLearnt

        case .deleteTapped:
            guard let id = state.wordID else { return }
            write(failure: VocabularyError.deleteWordsFailed) { [deleteWords] in
                try await deleteWords(ids: [id])
            }

        case .cancelTapped:
            effectChannel.send(.dismiss)
        }
    }

    private static func isBlank(_ meaning: String) -> Bool {
        meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Live, so a deck made or deleted while the editor is open is offered or taken away.
    /// A saved word is offered no decks, so has nothing to hear once it is read in.
    private func observe() {
        guard state.wordID == nil || state.isLoading, observation == nil else { return }
        let stream = observeVocabulary()
        observation = Task { [weak self] in
            for await vocabulary in stream {
                guard let self else { return }
                guard state.isLoading else {
                    state.vocabulary = vocabulary
                    continue
                }
                if let word = vocabulary.words.first(where: { $0.id == self.state.wordID }) {
                    state.load(word)
                    suggest()
                } else {
                    // Deleted since the dictionary listed it, so there is nothing to edit.
                    effectChannel.send(.dismiss)
                }
                return
            }
        }
    }

    /// The lexicon and the dictionary are asked separately, so either failing still leaves
    /// what the other knows.
    private func suggest() {
        suggestionTask?.cancel()
        let hanzi = state.draft.trimmed.hanzi
        suggestionTask = Task { [suggestWord, lookUpDictionary, suggestionDelay] in
            do {
                try await Task.sleep(for: suggestionDelay)
            } catch {
                return // Superseded by later typing, not a failure.
            }
            async let suggestion = Self.hint(failure: VocabularyError.suggestWordFailed) {
                try await suggestWord(hanzi: hanzi)
            }
            async let entries = Self.hint(failure: VocabularyError.lookUpDictionaryFailed) {
                try await lookUpDictionary(hanzi: hanzi)
            }
            let lookup = WordEditorState.Lookup(hanzi: hanzi, suggestion: await suggestion ?? nil, entries: await entries ?? [])
            guard !Task.isCancelled else { return }
            state.lookup = lookup
        }
    }

    /// Nil on failure, which is logged but not shown: an alert while typing would cost more
    /// than a missing hint.
    private nonisolated static func hint<T: Sendable>(
        failure makeError: (VocabularyDomainError) -> VocabularyError,
        _ work: () async throws -> T
    ) async -> T? {
        do {
            return try await work()
        } catch is CancellationError {
            return nil
        } catch {
            makeError(VocabularyDomainError(error)).log()
            return nil
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
