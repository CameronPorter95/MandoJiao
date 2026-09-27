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
    private let createDeck: CreateDeckUseCase
    private let createFolder: CreateFolderUseCase
    private let deleteDeck: DeleteDeckUseCase

    private var observation: Task<Void, Never>?
    /// Writes run one after another, so they land in the order they were made.
    private var lastWrite: Task<Void, Never>?

    /// `vocabulary` is shown until the store's own snapshot arrives.
    public init(
        folderID: UUID,
        minimumMatchingWords: Int,
        vocabulary: Vocabulary = .empty,
        observeVocabulary: ObserveVocabularyUseCase,
        createDeck: CreateDeckUseCase,
        createFolder: CreateFolderUseCase,
        deleteDeck: DeleteDeckUseCase
    ) {
        state = FolderDetailState(folderID: folderID, minimumMatchingWords: minimumMatchingWords, vocabulary: vocabulary)
        self.observeVocabulary = observeVocabulary
        self.createDeck = createDeck
        self.createFolder = createFolder
        self.deleteDeck = deleteDeck
    }

    func effects() -> AsyncStream<FolderDetailEffect> { effectChannel.stream() }

    func send(_ action: FolderDetailAction) {
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

        case .startLessonTapped:
            guard let folder = state.folder, state.canStartLesson else { return }
            requestLesson(title: folder.name, pool: state.vocabulary.words(in: folder).pairs)

        case .newItemTapped(let item):
            state.newName = ""
            state.naming = item

        case .newNameChanged(let name):
            state.newName = name

        case .createConfirmed:
            guard let item = state.naming else { return }
            state.naming = nil
            let name = state.newName
            let folderID = state.folderID
            switch item {
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

        case .practiseDeckTapped(let id):
            guard let deck = state.vocabulary.deck(id: id) else { return }
            requestLesson(title: deck.name, pool: state.vocabulary.words(in: deck).pairs)

        case .deleteDeckTapped(let id):
            let previous = state.vocabulary
            state.vocabulary.decks.removeAll { $0.id == id }
            enqueue(failure: VocabularyError.deleteDeckFailed, revertingTo: previous) { [deleteDeck] in
                try await deleteDeck(id: id)
            }
        }
    }

    private func requestLesson(title: String, pool: [WordPair]) {
        guard pool.count >= state.minimumMatchingWords else { return }
        effectChannel.send(.startLesson(LessonRequest(title: title, pool: pool)))
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
