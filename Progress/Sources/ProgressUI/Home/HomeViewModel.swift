import CoreUI
import Foundation
import LibraryDomain
import Observation

@MainActor
@Observable
public final class HomeViewModel {
    private(set) var state: HomeState

    private let effectChannel = EffectChannel<HomeEffect>()
    private let observeVocabulary: ObserveVocabularyUseCase
    private let getLessonSettings: GetLessonSettingsUseCase
    private let clearMistakes: ClearMistakesUseCase
    private let quickPracticeRounds: () -> Int
    private let now: () -> Date
    private var observation: Task<Void, Never>?
    /// When anything was last practised, so a pick is dropped once something newer is.
    private var lastPractisedAt: Date?

    public init(
        minimumMatchingWords: Int,
        quickPracticeRounds: @escaping () -> Int,
        observeVocabulary: ObserveVocabularyUseCase,
        getLessonSettings: GetLessonSettingsUseCase,
        clearMistakes: ClearMistakesUseCase,
        now: @escaping () -> Date = { .now }
    ) {
        state = HomeState(minimumMatchingWords: minimumMatchingWords, quickPracticeRounds: quickPracticeRounds())
        self.quickPracticeRounds = quickPracticeRounds
        self.observeVocabulary = observeVocabulary
        self.getLessonSettings = getLessonSettings
        self.clearMistakes = clearMistakes
        self.now = now
    }

    func effects() -> AsyncStream<HomeEffect> { effectChannel.stream() }

    func send(_ action: HomeAction) {
        switch action {
        case .appeared:
            // On every appearance, since the setting can change while this is underneath.
            state.lessonSettings = getLessonSettings()
            state.now = now()
            state.quickPracticeRounds = quickPracticeRounds()
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

        case .quickPracticeTapped:
            requestMatching(title: "All words", pool: state.quickPracticeWords.pairs)

        case .todayPlanTapped:
            guard let plan = state.todayPlan else { return }
            effectChannel.send(.requestTodayPlan(plan))

        case .continueTapped(let exercise):
            guard let source = state.current, let name = state.currentName, state.canStart(exercise) else { return }
            let request = LessonRequest(
                title: name, pool: state.currentLessonWords.pairs, source: source,
                otherWords: state.vocabulary.usableWords.pairs
            )
            switch exercise {
            case .matching: effectChannel.send(.requestMatching(request))
            case .flashcards: effectChannel.send(.requestFlashcards(request))
            case .speaking: effectChannel.send(.requestSpeaking(request))
            }

        case .chooseSourceTapped:
            state.isChoosingSource = true

        case .sourceChosen(let source):
            state.chosen = source
            state.isChoosingSource = false

        case .sourceChoiceDismissed:
            state.isChoosingSource = false

        case .practiseMistakesTapped:
            // A speaking lesson is one card per word, so any number of mistakes works. No
            // five-word floor, and nothing is padded in to fill a round.
            effectChannel.send(.requestSpeaking(LessonRequest(title: "Mistakes", pool: state.mistakeWords.pairs)))

        case .clearMistakesTapped:
            state.isConfirmingClear = true

        case .clearMistakesConfirmed:
            state.isConfirmingClear = false
            write(failure: ProgressError.clearMistakesFailed) { [clearMistakes] in
                try await clearMistakes()
            }

        case .clearMistakesCancelled:
            state.isConfirmingClear = false

        case .opened(let destination):
            state.destination = destination

        case .destinationDismissed:
            state.destination = nil
        }
    }

    /// A deck or folder picked to carry on with gives way once a lesson anywhere is recorded,
    /// since the one practised last is then what to carry on with.
    private func receive(_ vocabulary: Vocabulary) {
        state.vocabulary = vocabulary
        state.now = now()
        let practisedAt = vocabulary.lastPractisedAt
        if practisedAt != lastPractisedAt, lastPractisedAt != nil || practisedAt != nil {
            state.chosen = nil
        }
        lastPractisedAt = practisedAt
    }

    private func requestMatching(title: String, pool: [WordPair]) {
        guard pool.count >= state.minimumMatchingWords else { return }
        effectChannel.send(.requestMatching(LessonRequest(title: title, pool: pool)))
    }

    private func write(
        revertingTo previous: Vocabulary? = nil,
        failure: @escaping (VocabularyDomainError) -> ProgressError,
        _ work: @escaping () async throws -> Void
    ) {
        Task {
            let outcome = await ProgressError.performing(work, failure: failure) {
                effectChannel.send(.showError($0))
            }
            if outcome == .failed, let previous {
                state.vocabulary = previous
            }
        }
    }
}
