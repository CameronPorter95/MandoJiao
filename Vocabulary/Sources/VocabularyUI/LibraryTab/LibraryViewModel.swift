import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class LibraryViewModel {
    private(set) var state: LibraryState

    private let effectChannel = EffectChannel<LibraryEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let getLessonSettings: GetLessonSettingsUseCase
    private let createFolder: CreateFolderUseCase
    private let renameFolder: RenameFolderUseCase
    private let moveFolder: MoveFolderUseCase
    private let deleteFolder: DeleteFolderUseCase
    private let saveLayout: SaveLibraryLayoutUseCase

    private var observation: Task<Void, Never>?
    /// Writes run one after another, so drags land in the order they were made.
    private var lastWrite: Task<Void, Never>?

    public init(
        minimumMatchingWords: Int,
        observeVocabulary: ObserveVocabularyUseCase,
        getLessonSettings: GetLessonSettingsUseCase,
        createFolder: CreateFolderUseCase,
        renameFolder: RenameFolderUseCase,
        moveFolder: MoveFolderUseCase,
        deleteFolder: DeleteFolderUseCase,
        getLayout: GetLibraryLayoutUseCase,
        saveLayout: SaveLibraryLayoutUseCase
    ) {
        state = LibraryState(minimumMatchingWords: minimumMatchingWords, layout: getLayout())
        self.observeVocabulary = observeVocabulary
        self.getLessonSettings = getLessonSettings
        self.createFolder = createFolder
        self.renameFolder = renameFolder
        self.moveFolder = moveFolder
        self.deleteFolder = deleteFolder
        self.saveLayout = saveLayout
    }

    func effects() -> AsyncStream<LibraryEffect> { effectChannel.stream() }

    func send(_ action: LibraryAction) {
        switch action {
        case .appeared:
            // On every appearance, since the setting can change while this is underneath.
            state.lessonSettings = getLessonSettings()
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

        case .selected(let selection):
            state.selection = selection
            state.path = []

        case .opened(let page):
            state.path.append(page)

        case .pathChanged(let path):
            state.path = path

        case .folderExpanded(let id, let isExpanded, let scope):
            state.layout = state.layout.settingExpanded(id, isExpanded, in: scope)
            saveLayout(state.layout)

        case .folderSectionToggled(let id, let section):
            state.layout = state.layout.toggling(section, in: id)
            saveLayout(state.layout)

        case .deckSortChanged(let id, let sort):
            state.layout = state.layout.settingDeckSort(sort, in: id)
            saveLayout(state.layout)

        case .wordSortChanged(let sort):
            state.layout = state.layout.settingWordSort(sort)
            saveLayout(state.layout)

        case .hskLevelsTapped:
            state.isShowingHSKLevels = true

        case .hskLevelsDismissed:
            state.isShowingHSKLevels = false

        case .searchPresentedChanged(let isPresented):
            state.isSearching = isPresented

        case .searchChanged(let text):
            state.searchText = text

        case .newWordTapped:
            state.editor = .new(WordDraft())

        case .editorDismissed:
            state.editor = nil

        case .editTapped:
            state.isEditing.toggle()

        case .folderMoved(let id, let parentID, let index):
            guard state.vocabulary.canMoveFolder(id, into: parentID) else { return }
            let previous = state.vocabulary
            state.vocabulary = previous.movingFolder(id, into: parentID, at: index)
            enqueue(failure: VocabularyError.moveFolderFailed, revertingTo: previous) { [moveFolder] in
                try await moveFolder(id: id, toParent: parentID, at: index)
            }

        case .newFolderTapped(let parentID):
            state.name = ""
            state.naming = .new(parentID: parentID)

        case .renameFolderTapped(let id):
            state.name = state.vocabulary.folder(id: id)?.name ?? ""
            state.naming = .rename(id)

        case .nameChanged(let name):
            state.name = name

        case .namingConfirmed:
            guard let naming = state.naming else { return }
            state.naming = nil
            let name = state.name
            switch naming {
            case .new(let parentID):
                enqueue(failure: VocabularyError.createFolderFailed) { [createFolder] in
                    try await createFolder(name: name, parentID: parentID)
                }
            case .rename(let id):
                enqueue(failure: VocabularyError.renameFolderFailed) { [renameFolder] in
                    try await renameFolder(id: id, name: name)
                }
            }

        case .namingCancelled:
            state.naming = nil

        case .practiseFolderTapped(let id):
            guard let folder = state.vocabulary.folder(id: id) else { return }
            guard state.canPractise(id) else { return }
            let pool = state.lessonWords(in: id).pairs
            effectChannel.send(.requestMatching(LessonRequest(title: folder.name, pool: pool, source: .folder(id))))

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

    /// Anything open that no longer exists is closed, with everything pushed over it.
    private func receive(_ vocabulary: Vocabulary) {
        state.vocabulary = vocabulary
        if case .folder(let id) = state.selection, vocabulary.folder(id: id) == nil {
            state.selection = nil
            state.path = []
        }
        if let gone = state.path.firstIndex(where: { page in
            switch page {
            case .folder(let id): vocabulary.folder(id: id) == nil
            case .deck(let id): vocabulary.deck(id: id) == nil
            }
        }) {
            state.path.removeSubrange(gone...)
        }
    }

    private func removeFolder(_ id: UUID) {
        let previous = state.vocabulary
        receive(previous.removingFolder(id))
        enqueue(failure: VocabularyError.deleteFolderFailed, revertingTo: previous) { [deleteFolder] in
            try await deleteFolder(id: id)
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
