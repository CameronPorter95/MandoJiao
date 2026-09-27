import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class FolderDetailViewModel {
    private(set) var state: FolderDetailState

    private let effectChannel = EffectChannel<FolderDetailEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let renameFolder: RenameFolderUseCase
    private let moveFolder: MoveFolderUseCase
    private let createDeck: CreateDeckUseCase
    private let createFolder: CreateFolderUseCase
    private let deleteDeck: DeleteDeckUseCase
    private let deleteFolder: DeleteFolderUseCase
    private let renameDelay: Duration

    private var observation: Task<Void, Never>?
    private var pendingName: String?
    private var renameDebounce: Task<Void, Never>?
    /// Writes run one after another, so they land in the order they were made.
    private var lastWrite: Task<Void, Never>?

    public init(
        folderID: UUID,
        minimumMatchingWords: Int,
        observeVocabulary: ObserveVocabularyUseCase,
        renameFolder: RenameFolderUseCase,
        moveFolder: MoveFolderUseCase,
        createDeck: CreateDeckUseCase,
        createFolder: CreateFolderUseCase,
        deleteDeck: DeleteDeckUseCase,
        deleteFolder: DeleteFolderUseCase,
        renameDelay: Duration = .milliseconds(300)
    ) {
        state = FolderDetailState(folderID: folderID, minimumMatchingWords: minimumMatchingWords)
        self.observeVocabulary = observeVocabulary
        self.renameFolder = renameFolder
        self.moveFolder = moveFolder
        self.createDeck = createDeck
        self.createFolder = createFolder
        self.deleteDeck = deleteDeck
        self.deleteFolder = deleteFolder
        self.renameDelay = renameDelay
    }

    func effects() -> AsyncStream<FolderDetailEffect> { effectChannel.stream() }

    func send(_ action: FolderDetailAction) {
        switch action {
        case .appeared:
            guard observation == nil else { return }
            let stream = observeVocabulary()
            observation = Task { [weak self] in
                for await vocabulary in stream {
                    self?.receive(vocabulary)
                }
            }

        case .disappeared:
            observation?.cancel()
            observation = nil
            flushRename()

        case .nameChanged(let name):
            state.name = name
            pendingName = name
            renameDebounce?.cancel()
            renameDebounce = Task { [weak self, renameDelay] in
                try? await Task.sleep(for: renameDelay)
                guard !Task.isCancelled else { return }
                self?.flushRename()
            }

        case .startLessonTapped:
            guard let folder = state.folder, state.canStartLesson else { return }
            flushRename()
            requestLesson(title: state.name ?? folder.name, pool: state.vocabulary.words(in: folder).pairs)

        case .newItemTapped(let kind):
            state.newItemName = ""
            state.naming = kind

        case .newItemNameChanged(let name):
            state.newItemName = name

        case .createConfirmed:
            guard let kind = state.naming else { return }
            state.naming = nil
            let name = state.newItemName
            let folderID = state.folderID
            switch kind {
            case .deck:
                enqueue(failure: VocabularyError.createDeckFailed) { [createDeck] in
                    try await createDeck(name: name, folderID: folderID)
                }
            case .folder:
                enqueue(failure: VocabularyError.createFolderFailed) { [createFolder] in
                    try await createFolder(name: name, parentID: folderID)
                }
            }

        case .createCancelled:
            state.naming = nil

        case .practiseFolderTapped(let id):
            guard let folder = state.vocabulary.folder(id: id) else { return }
            requestLesson(title: folder.name, pool: state.vocabulary.words(in: folder).pairs)

        case .practiseDeckTapped(let id):
            guard let deck = state.vocabulary.deck(id: id) else { return }
            requestLesson(title: deck.name, pool: state.vocabulary.words(in: deck).pairs)

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

        case .deleteDeckTapped(let id):
            let previous = state.vocabulary
            state.vocabulary.decks.removeAll { $0.id == id }
            enqueue(failure: VocabularyError.deleteDeckFailed, revertingTo: previous) { [deleteDeck] in
                try await deleteDeck(id: id)
            }

        case .moveTapped:
            state.isChoosingDestination = true

        case .destinationChosen(let parentID):
            state.isChoosingDestination = false
            guard state.vocabulary.canMoveFolder(state.folderID, into: parentID),
                  let index = state.vocabulary.folders.firstIndex(where: { $0.id == state.folderID })
            else { return }
            let previous = state.vocabulary
            state.vocabulary.folders[index] = previous.folders[index].with(parentID: .some(parentID))
            let folderID = state.folderID
            enqueue(failure: VocabularyError.moveFolderFailed, revertingTo: previous) { [moveFolder] in
                try await moveFolder(id: folderID, toParent: parentID)
            }

        case .moveCancelled:
            state.isChoosingDestination = false
        }
    }

    private func receive(_ vocabulary: Vocabulary) {
        state.vocabulary = vocabulary
        if state.name == nil { state.name = state.folder?.name }
    }

    private func requestLesson(title: String, pool: [WordPair]) {
        guard pool.count >= state.minimumMatchingWords else { return }
        effectChannel.send(.startLesson(LessonRequest(title: title, pool: pool)))
    }

    private func removeFolder(_ id: UUID) {
        let previous = state.vocabulary
        state.vocabulary = previous.removingFolder(id)
        enqueue(failure: VocabularyError.deleteFolderFailed, revertingTo: previous) { [deleteFolder] in
            try await deleteFolder(id: id)
        }
    }

    private func flushRename() {
        renameDebounce?.cancel()
        renameDebounce = nil
        guard let name = pendingName else { return }
        pendingName = nil
        let folderID = state.folderID
        enqueue(failure: VocabularyError.renameFolderFailed) { [renameFolder] in
            try await renameFolder(id: folderID, name: name)
        }
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
