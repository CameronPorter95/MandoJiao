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
    private let deleteDeck: DeleteDeckUseCase
    private let moveDeck: MoveDeckUseCase

    private var observation: Task<Void, Never>?
    /// Writes run one after another, so they land in the order they were made.
    private var lastWrite: Task<Void, Never>?

    /// Nil `folderID` lists the decks at the top level.
    public init(
        folderID: UUID?,
        minimumMatchingWords: Int,
        observeVocabulary: ObserveVocabularyUseCase,
        createDeck: CreateDeckUseCase,
        deleteDeck: DeleteDeckUseCase,
        moveDeck: MoveDeckUseCase
    ) {
        state = FolderDetailState(folderID: folderID, minimumMatchingWords: minimumMatchingWords)
        self.observeVocabulary = observeVocabulary
        self.createDeck = createDeck
        self.deleteDeck = deleteDeck
        self.moveDeck = moveDeck
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

        case .newDeckTapped:
            state.newDeckName = ""
            state.isNamingDeck = true

        case .newDeckNameChanged(let name):
            state.newDeckName = name

        case .createDeckConfirmed:
            state.isNamingDeck = false
            let name = state.newDeckName
            let folderID = state.folderID
            enqueue(failure: VocabularyError.createDeckFailed) { [createDeck] in
                try await createDeck(name: name, folderID: folderID)
            }

        case .createDeckCancelled:
            state.isNamingDeck = false

        case .practiseDeckTapped(let id):
            guard let deck = state.vocabulary.deck(id: id) else { return }
            requestLesson(title: deck.name, pool: state.vocabulary.words(in: deck).pairs)

        case .deleteDeckTapped(let id):
            let previous = state.vocabulary
            state.vocabulary.decks.removeAll { $0.id == id }
            enqueue(failure: VocabularyError.deleteDeckFailed, revertingTo: previous) { [deleteDeck] in
                try await deleteDeck(id: id)
            }

        case .decksMoved(let offsets, let destination):
            let decks = state.decks
            guard offsets.count == 1, let from = offsets.first, decks.indices.contains(from) else { return }
            // List reports the destination counting the row being moved; the domain does not.
            let index = destination > from ? destination - 1 : destination
            let deckID = decks[from].id
            let folderID = state.folderID
            let previous = state.vocabulary
            state.vocabulary = previous.movingDeck(deckID, into: folderID, at: index)
            enqueue(failure: VocabularyError.moveDeckFailed, revertingTo: previous) { [moveDeck] in
                try await moveDeck(id: deckID, toFolder: folderID, at: index)
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
