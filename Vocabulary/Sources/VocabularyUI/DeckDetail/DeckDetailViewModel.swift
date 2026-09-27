import CoreUI
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class DeckDetailViewModel {
    private(set) var state: DeckDetailState

    private let effectChannel = EffectChannel<DeckDetailEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let renameDeck: RenameDeckUseCase
    private let setMembership: SetDeckMembershipUseCase
    private let renameDelay: Duration

    private var observation: Task<Void, Never>?
    private var pendingName: String?
    private var renameDebounce: Task<Void, Never>?
    /// Writes run one after another, so rapid toggles land in the order they were made.
    private var lastWrite: Task<Void, Never>?

    public init(
        deckID: UUID,
        minimumMatchingWords: Int,
        observeVocabulary: ObserveVocabularyUseCase,
        renameDeck: RenameDeckUseCase,
        setMembership: SetDeckMembershipUseCase,
        renameDelay: Duration = .milliseconds(300)
    ) {
        state = DeckDetailState(deckID: deckID, minimumMatchingWords: minimumMatchingWords)
        self.observeVocabulary = observeVocabulary
        self.renameDeck = renameDeck
        self.setMembership = setMembership
        self.renameDelay = renameDelay
    }

    func effects() -> AsyncStream<DeckDetailEffect> { effectChannel.stream() }

    func send(_ action: DeckDetailAction) {
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

        case .searchChanged(let text):
            state.searchText = text

        case .wordToggled(let wordID):
            guard state.deck != nil else { return }
            let isIncluded = !state.isIncluded(wordID)
            applyMembership(of: wordID, isIncluded: isIncluded)
            let deckID = state.deckID
            enqueue(failure: VocabularyError.updateDeckFailed, revert: { [weak self] in
                self?.applyMembership(of: wordID, isIncluded: !isIncluded)
            }) { [setMembership] in
                try await setMembership(deckID: deckID, wordID: wordID, isIncluded: isIncluded)
            }

        case .startLessonTapped:
            guard let deck = state.deck, state.canStartLesson else { return }
            flushRename()
            let request = LessonRequest(
                title: state.name ?? deck.name,
                pool: state.vocabulary.words(in: deck).pairs
            )
            effectChannel.send(.startLesson(request))
        }
    }

    private func receive(_ vocabulary: Vocabulary) {
        state.vocabulary = vocabulary
        if state.name == nil { state.name = state.deck?.name }
    }

    private func applyMembership(of wordID: UUID, isIncluded: Bool) {
        guard let index = state.vocabulary.decks.firstIndex(where: { $0.id == state.deckID }) else { return }
        state.vocabulary.decks[index] = state.vocabulary.decks[index].settingMembership(of: wordID, to: isIncluded)
    }

    private func flushRename() {
        renameDebounce?.cancel()
        renameDebounce = nil
        guard let name = pendingName else { return }
        pendingName = nil
        let deckID = state.deckID
        enqueue(failure: VocabularyError.renameDeckFailed, revert: {}) { [renameDeck] in
            try await renameDeck(id: deckID, name: name)
        }
    }

    private func enqueue(
        failure: @escaping (VocabularyDomainError) -> VocabularyError,
        revert: @escaping () -> Void,
        _ work: @escaping () async throws -> Void
    ) {
        let previous = lastWrite
        lastWrite = Task {
            await previous?.value
            let outcome = await VocabularyError.performing(work, failure: failure) {
                effectChannel.send(.showError($0))
            }
            if outcome == .failed { revert() }
        }
    }
}
