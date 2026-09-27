import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class HomeViewModel {
    private(set) var state: HomeState

    private let effectChannel = EffectChannel<HomeEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let createDeck: CreateDeckUseCase
    private let deleteDeck: DeleteDeckUseCase
    private let createFolder: CreateFolderUseCase
    private let deleteFolder: DeleteFolderUseCase
    private let clearMistakes: ClearMistakesUseCase
    private let quickPracticeRounds: () -> Int
    private var observation: Task<Void, Never>?

    public init(
        minimumMatchingWords: Int,
        quickPracticeRounds: @escaping () -> Int,
        observeVocabulary: ObserveVocabularyUseCase,
        createDeck: CreateDeckUseCase,
        deleteDeck: DeleteDeckUseCase,
        createFolder: CreateFolderUseCase,
        deleteFolder: DeleteFolderUseCase,
        clearMistakes: ClearMistakesUseCase
    ) {
        state = HomeState(minimumMatchingWords: minimumMatchingWords, quickPracticeRounds: quickPracticeRounds())
        self.quickPracticeRounds = quickPracticeRounds
        self.observeVocabulary = observeVocabulary
        self.createDeck = createDeck
        self.deleteDeck = deleteDeck
        self.createFolder = createFolder
        self.deleteFolder = deleteFolder
        self.clearMistakes = clearMistakes
    }

    func effects() -> AsyncStream<HomeEffect> { effectChannel.stream() }

    func send(_ action: HomeAction) {
        switch action {
        case .appeared:
            state.quickPracticeRounds = quickPracticeRounds()
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

        case .quickPracticeTapped:
            requestMatching(title: "All words", pool: state.vocabulary.usableWords.pairs)

        case .practiseMistakesTapped:
            // A speaking lesson is one card per word, so any number of mistakes works. No
            // five-word floor, and nothing is padded in to fill a round.
            effectChannel.send(.requestSpeaking(LessonRequest(title: "Mistakes", pool: state.mistakeWords.pairs)))

        case .practiseDeckTapped(let id):
            guard let deck = state.vocabulary.deck(id: id) else { return }
            requestMatching(title: deck.name, pool: state.vocabulary.words(in: deck).pairs)

        case .practiseFolderTapped(let id):
            guard let folder = state.vocabulary.folder(id: id) else { return }
            requestMatching(title: folder.name, pool: state.vocabulary.words(in: folder).pairs)

        case .deleteDeckTapped(let id):
            let previous = state.vocabulary
            state.vocabulary.decks.removeAll { $0.id == id }
            write(revertingTo: previous, failure: VocabularyError.deleteDeckFailed) { [deleteDeck] in
                try await deleteDeck(id: id)
            }

        case .deleteFolderTapped(let id):
            if state.vocabulary.deletionWarning(forFolder: id) != nil {
                state.pendingFolderDeletion = id
            } else {
                removeFolder(id)
            }

        case .deleteFolderConfirmed:
            guard let id = state.pendingFolderDeletion else { return }
            state.pendingFolderDeletion = nil
            removeFolder(id)

        case .deleteFolderCancelled:
            state.pendingFolderDeletion = nil

        case .newItemTapped(let kind):
            state.newItemName = ""
            state.naming = kind

        case .newItemNameChanged(let name):
            state.newItemName = name

        case .createConfirmed:
            guard let kind = state.naming else { return }
            state.naming = nil
            let name = state.newItemName
            switch kind {
            case .deck:
                write(failure: VocabularyError.createDeckFailed) { [createDeck] in
                    try await createDeck(name: name)
                }
            case .folder:
                write(failure: VocabularyError.createFolderFailed) { [createFolder] in
                    try await createFolder(name: name)
                }
            }

        case .createCancelled:
            state.naming = nil

        case .clearMistakesTapped:
            state.isConfirmingClear = true

        case .clearMistakesConfirmed:
            state.isConfirmingClear = false
            write(failure: VocabularyError.clearMistakesFailed) { [clearMistakes] in
                try await clearMistakes()
            }

        case .clearMistakesCancelled:
            state.isConfirmingClear = false
        }
    }

    private func removeFolder(_ id: UUID) {
        let previous = state.vocabulary
        state.vocabulary = previous.removingFolder(id)
        write(revertingTo: previous, failure: VocabularyError.deleteFolderFailed) { [deleteFolder] in
            try await deleteFolder(id: id)
        }
    }

    private func requestMatching(title: String, pool: [WordPair]) {
        guard pool.count >= state.minimumMatchingWords else { return }
        effectChannel.send(.requestMatching(LessonRequest(title: title, pool: pool)))
    }

    private func write(
        revertingTo previous: Vocabulary? = nil,
        failure: @escaping (VocabularyDomainError) -> VocabularyError,
        _ work: @escaping () async throws -> Void
    ) {
        Task {
            let outcome = await VocabularyError.performing(work, failure: failure) {
                effectChannel.send(.showError($0))
            }
            if outcome == .failed, let previous {
                state.vocabulary = previous
            }
        }
    }
}
