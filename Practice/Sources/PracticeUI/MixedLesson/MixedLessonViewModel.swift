import CoreDomain
import CoreUI
import Foundation
import LibraryDomain
import Observation
import PracticeDomain

@MainActor
@Observable
public final class MixedLessonViewModel {
    private(set) var state: MixedLessonState

    private let effectChannel = EffectChannel<MixedLessonEffect>()
    private let recordResults: RecordLessonResultsUseCase
    private let sounds: any MatchSoundPlaying
    private var didRecordResults = false

    public init(lesson: MixedLesson, recordResults: RecordLessonResultsUseCase, sounds: any MatchSoundPlaying) {
        state = MixedLessonState(lesson: lesson)
        self.recordResults = recordResults
        self.sounds = sounds
    }

    func effects() -> AsyncStream<MixedLessonEffect> { effectChannel.stream() }

    func send(_ action: MixedLessonAction) {
        switch action {
        case .stepCompleted(let answers):
            guard !state.lesson.isFinished else { return }
            state.lesson.complete(with: answers)
            guard state.lesson.isFinished else { return }
            sounds.playLessonComplete()
            // Recorded as soon as the last step is done, so the review and the strengths
            // agree even if the app is killed from here.
            recordResultsOnce()

        case .practiseAgainTapped:
            // The same plan again, its cards dealt afresh; this run's answers stand.
            recordResultsOnce()
            didRecordResults = false
            state.lesson = MixedLesson(plan: state.lesson.plan)

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

    private func close() {
        recordResultsOnce()
        effectChannel.send(.close)
    }

    private func recordResultsOnce() {
        guard !didRecordResults else { return }
        didRecordResults = true
        let results = state.lesson.results

        // Outlives a close on purpose: the lesson has gone, but the results still land.
        Task { [recordResults] in
            do {
                try await recordResults(results)
            } catch is CancellationError {
                // Cancelled, not a failure.
            } catch {
                let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                let displayError = MixedLessonError.recordResultsFailed(domainError)
                displayError.log()
                effectChannel.send(.showError(displayError))
            }
        }
    }
}
