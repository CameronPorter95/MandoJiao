import CoreDomain
import CoreUI
import Foundation
import MatchingDomain
import Observation
import VocabularyDomain

/// Runs a matching lesson: the boards, the tones, the pause between boards, and writing
/// results back.
@MainActor
@Observable
public final class MatchingViewModel {
    private(set) var state: MatchingState

    private let effectChannel = EffectChannel<MatchingEffect>()
    private let request: LessonRequest
    private let sounds: any MatchSoundPlaying
    private let getSettings: GetMatchingSettingsUseCase
    private let setShowsPinyin: SetShowsPinyinUseCase
    private let recordResults: RecordLessonResultsUseCase
    private let advanceDelay: Duration

    private var didRecordResults = false
    private var advanceTask: Task<Void, Never>?

    /// `advanceDelay` is long enough for the last tile to read as matched, short enough
    /// that it never feels like waiting.
    public init(
        request: LessonRequest,
        sounds: any MatchSoundPlaying,
        getSettings: GetMatchingSettingsUseCase,
        setShowsPinyin: SetShowsPinyinUseCase,
        recordResults: RecordLessonResultsUseCase,
        advanceDelay: Duration = .milliseconds(320)
    ) {
        self.request = request
        self.sounds = sounds
        self.getSettings = getSettings
        self.setShowsPinyin = setShowsPinyin
        self.recordResults = recordResults
        self.advanceDelay = advanceDelay
        state = MatchingState(title: request.title)
    }

    func effects() -> AsyncStream<MatchingEffect> { effectChannel.stream() }

    func send(_ action: MatchingAction) {
        switch action {
        case .appeared:
            if state.lesson == nil { startLesson() }
            sounds.prepare()

        case .tileTapped(let tile):
            tap(tile)

        case .pinyinToggled:
            state.showsPinyin.toggle()
            setShowsPinyin(state.showsPinyin)

        case .practiseAgainTapped:
            startLesson()

        case .closeTapped:
            if state.canCloseWithoutConfirming {
                close()
            } else {
                state.isConfirmingQuit = true
            }

        case .quitConfirmed:
            state.isConfirmingQuit = false
            close()

        case .quitCancelled:
            state.isConfirmingQuit = false
        }
    }

    // MARK: - Boards

    private func tap(_ tile: Tile) {
        guard let result = state.lesson?.tap(tile), let lesson = state.lesson else { return }

        switch result {
        case .matched(let step, let boardComplete, _):
            sounds.playMatch(step: step, of: lesson.board.pairs.count)
            effectChannel.send(.haptic(boardComplete ? .success : .match))
            if boardComplete { scheduleAdvance() }
        case .missed:
            sounds.playMiss()
            effectChannel.send(.haptic(.miss))
        case .selected, .switched:
            effectChannel.send(.haptic(.selection))
        case .deselected, .ignored:
            break
        }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task { [advanceDelay] in
            try? await Task.sleep(for: advanceDelay)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        advanceTask = nil
        state.lesson?.advance()
        guard state.lesson?.isFinished == true else { return }

        sounds.playLessonComplete()
        // Recorded as soon as the last board is cleared, so the review screen and the
        // mistakes list agree even if the app is killed from here.
        recordResultsOnce()
    }

    // MARK: - Lesson

    private func startLesson() {
        // Practising again starts a fresh tally, so the previous lesson's mistakes are
        // not written a second time.
        recordResultsOnce()
        didRecordResults = false
        advanceTask?.cancel()
        advanceTask = nil

        let settings = getSettings()
        state.showsPinyin = settings.showsPinyin
        state.lesson = MatchingPlanBuilder.makeLesson(
            title: request.title,
            from: request.pool,
            exerciseCount: settings.rounds
        ).map(MatchingLesson.init(plan:))
    }

    private func close() {
        recordResultsOnce()
        effectChannel.send(.close)
    }

    private func recordResultsOnce() {
        guard let lesson = state.lesson, !didRecordResults else { return }
        didRecordResults = true
        let results = LessonResults(misses: lesson.missesByPairID, cleanSolves: lesson.cleanSolvesByPairID, answers: lesson.answers)

        // Outlives a close on purpose: the lesson has gone, but the results still land.
        Task { [recordResults] in
            do {
                try await recordResults(results)
            } catch is CancellationError {
                // Cancelled, not a failure.
            } catch {
                let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                let displayError = MatchingError.recordResultsFailed(domainError)
                displayError.log()
                effectChannel.send(.showError(displayError))
            }
        }
    }
}
