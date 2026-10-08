import CoreUI
import Foundation
import LibraryDomain
import Observation

@MainActor
@Observable
public final class FolderDetailViewModel {
    private(set) var state: FolderDetailState

    private let effectChannel = EffectChannel<FolderDetailEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let getLessonSettings: GetLessonSettingsUseCase
    private let createDeck: CreateDeckUseCase
    private let createFolder: CreateFolderUseCase
    private let renameFolder: RenameFolderUseCase
    private let deleteDeck: DeleteDeckUseCase
    private let deleteFolder: DeleteFolderUseCase

    private var observation: Task<Void, Never>?
    /// Writes run one after another, so they land in the order they were made.
    private var lastWrite: Task<Void, Never>?

    /// `vocabulary` is shown until the store's own snapshot arrives.
    public init(
        folderID: UUID,
        minimumMatchingWords: Int,
        vocabulary: Vocabulary = .empty,
        observeVocabulary: ObserveVocabularyUseCase,
        getLessonSettings: GetLessonSettingsUseCase,
        createDeck: CreateDeckUseCase,
        createFolder: CreateFolderUseCase,
        renameFolder: RenameFolderUseCase,
        deleteDeck: DeleteDeckUseCase,
        deleteFolder: DeleteFolderUseCase
    ) {
        state = FolderDetailState(folderID: folderID, minimumMatchingWords: minimumMatchingWords, vocabulary: vocabulary)
        self.observeVocabulary = observeVocabulary
        self.getLessonSettings = getLessonSettings
        self.createDeck = createDeck
        self.createFolder = createFolder
        self.renameFolder = renameFolder
        self.deleteDeck = deleteDeck
        self.deleteFolder = deleteFolder
    }

    func effects() -> AsyncStream<FolderDetailEffect> { effectChannel.stream() }

    func send(_ action: FolderDetailAction) {
        switch action {
        case .appeared:
            // On every appearance, since the setting can change while this is underneath.
            state.lessonSettings = getLessonSettings()
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

        case .deckOpened(let id):
            effectChannel.send(.openDeck(id))

        case .folderOpened(let id):
            effectChannel.send(.openFolder(id))

        case .startLessonTapped(let exercise):
            guard let folder = state.folder, state.canStart(exercise) else { return }
            requestLesson(title: folder.name, pool: state.lessonWords(state.vocabulary.words(in: folder)).pairs, source: .folder(folder.id), exercise: exercise)

        case .searchPresentedChanged(let isPresented):
            state.isSearching = isPresented

        case .searchChanged(let text):
            state.searchText = text

        case .namingTapped(let naming):
            state.newName = naming == .rename ? state.folder?.name ?? "" : ""
            state.naming = naming

        case .newNameChanged(let name):
            state.newName = name

        case .namingConfirmed:
            guard let naming = state.naming else { return }
            state.naming = nil
            let name = state.newName
            let folderID = state.folderID
            switch naming {
            case .newDeck:
                enqueue(failure: VocabularyError.createDeckFailed) { [createDeck] in
                    try await createDeck(name: name, folderID: folderID)
                }
            case .newFolder:
                enqueue(failure: VocabularyError.createFolderFailed) { [createFolder] in
                    try await createFolder(name: name, parentID: folderID)
                }
            case .rename:
                enqueue(failure: VocabularyError.renameFolderFailed) { [renameFolder] in
                    try await renameFolder(id: folderID, name: name)
                }
            }

        case .namingCancelled:
            state.naming = nil

        case .practiseFolderTapped(let id):
            guard let folder = state.vocabulary.folder(id: id) else { return }
            requestLesson(title: folder.name, pool: state.lessonWords(state.vocabulary.words(in: folder)).pairs, source: .folder(id))

        case .practiseDeckTapped(let id):
            guard let deck = state.vocabulary.deck(id: id) else { return }
            requestLesson(title: deck.name, pool: state.lessonWords(state.vocabulary.words(in: deck)).pairs, source: .deck(id))

        case .deleteDeckTapped(let id):
            let previous = state.vocabulary
            state.vocabulary.decks.removeAll { $0.id == id }
            enqueue(failure: VocabularyError.deleteDeckFailed, revertingTo: previous) { [deleteDeck] in
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
        }
    }

    private func removeFolder(_ id: UUID) {
        let previous = state.vocabulary
        state.vocabulary = previous.removingFolder(id)
        enqueue(failure: VocabularyError.deleteFolderFailed, revertingTo: previous) { [deleteFolder] in
            try await deleteFolder(id: id)
        }
    }

    /// A swipe to practise a folder or deck beneath starts matching.
    private func requestLesson(title: String, pool: [WordPair], source: LessonSource, exercise: LessonExercise = .matching) {
        guard pool.count >= exercise.minimumWords(matching: state.minimumMatchingWords) else { return }
        let request = LessonRequest(title: title, pool: pool, source: source, otherWords: state.vocabulary.usableWords.pairs)
        effectChannel.send(.startLesson(request, exercise))
    }

    private func enqueue(
        failure: @escaping (VocabularyDomainError) -> VocabularyError,
        revertingTo previous: Vocabulary? = nil,
        _ work: @escaping () async throws -> Void
    ) {
        let last = lastWrite
        lastWrite = Task {
            await last?.value
            let outcome = await VocabularyError.performing(work, failure: failure) {
                effectChannel.send(.showError($0))
            }
            if outcome == .failed, let previous { state.vocabulary = previous }
        }
    }
}
