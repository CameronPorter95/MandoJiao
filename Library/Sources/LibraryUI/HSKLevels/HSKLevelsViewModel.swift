import CoreDomain
import CoreUI
import DictionaryDomain
import Foundation
import LibraryDomain
import Observation

@MainActor
@Observable
public final class HSKLevelsViewModel {
    private(set) var state = HSKLevelsState()

    private let effectChannel = EffectChannel<HSKLevelsEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let getWords: GetHSKWordsUseCase
    private let installLevel: InstallHSKLevelUseCase
    private var observation: Task<Void, Never>?

    public init(
        observeVocabulary: ObserveVocabularyUseCase,
        getWords: GetHSKWordsUseCase,
        installLevel: InstallHSKLevelUseCase
    ) {
        self.observeVocabulary = observeVocabulary
        self.getWords = getWords
        self.installLevel = installLevel
    }

    func effects() -> AsyncStream<HSKLevelsEffect> { effectChannel.stream() }

    func send(_ action: HSKLevelsAction) {
        switch action {
        case .appeared:
            guard observation == nil else { return }
            let stream = observeVocabulary()
            observation = Task { [weak self] in
                for await vocabulary in stream {
                    self?.state.vocabulary = vocabulary
                }
            }
            if state.words == nil { loadWords() }

        case .disappeared:
            observation?.cancel()
            observation = nil

        case .installTapped(let level):
            guard !state.installing.contains(level) else { return }
            state.installing.insert(level)
            let vocabulary = state.vocabulary
            Task {
                _ = await VocabularyError.performing({ [installLevel] in
                    try await installLevel(level: level, in: vocabulary)
                }, failure: VocabularyError.installHSKFailed) {
                    effectChannel.send(.showError($0))
                }
                state.installing.remove(level)
            }

        case .doneTapped:
            effectChannel.send(.dismiss)
        }
    }

    private func loadWords() {
        Task {
            do {
                state.words = try await getWords()
            } catch is CancellationError {
                // Closed before the list was read, not a failure.
            } catch {
                let displayError = VocabularyError.loadHSKFailed(
                    VocabularyDomainError(error)
                )
                displayError.log()
                effectChannel.send(.showError(displayError))
            }
        }
    }
}
