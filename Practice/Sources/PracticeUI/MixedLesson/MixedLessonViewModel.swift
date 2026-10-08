import CoreDomain
import CoreUI
import DictionaryDomain
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
    private let audioSession: any AudioSessionSwitching
    private let findExamples: FindExamplesUseCase
    private var didRecordResults = false
    private var examplesTask: Task<Void, Never>?

    /// `audioSession` is handed back from the microphone here rather than by each read-aloud
    /// step, so a run of them keeps it and a tone after one plays at the usual level.
    public init(
        lesson: MixedLesson,
        recordResults: RecordLessonResultsUseCase,
        findExamples: FindExamplesUseCase,
        sounds: any MatchSoundPlaying,
        audioSession: any AudioSessionSwitching
    ) {
        state = MixedLessonState(lesson: lesson)
        self.recordResults = recordResults
        self.findExamples = findExamples
        self.sounds = sounds
        self.audioSession = audioSession
    }

    func effects() -> AsyncStream<MixedLessonEffect> { effectChannel.stream() }

    func send(_ action: MixedLessonAction) {
        switch action {
        case .stepCompleted(let answers, let carriesOn):
            guard !state.lesson.isFinished else { return }
            state.lesson.complete(with: answers, carriesOn: carriesOn)
            guard state.lesson.isFinished else {
                if state.lesson.step?.listens != true { leaveRecordingMode() }
                return
            }
            // Recorded as soon as the last step is done, so the review and the strengths
            // agree even if the app is killed from here.
            recordResultsOnce()
            // After the microphone's session is handed back, or the fanfare plays quieter.
            Task { [audioSession, sounds] in
                await audioSession.exitRecordingMode()
                sounds.playLessonComplete()
            }

        case .appeared:
            loadExamples()

        case .disappeared:
            leaveRecordingMode()

        case .practiseAgainTapped:
            // The same plan again, its cards dealt afresh; this run's answers stand.
            recordResultsOnce()
            didRecordResults = false
            state.lesson = MixedLesson(plan: state.lesson.plan)
            leaveRecordingMode()

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
        leaveRecordingMode()
        effectChannel.send(.close)
    }

    /// One sentence for each word the lesson teaches, all looked up at the start so none is
    /// waited for on its card: the one with the fewest words the learner has not started.
    /// A failure is logged and the card shows no example: an alert mid-lesson would cost more
    /// than a missing sentence.
    private func loadExamples() {
        guard examplesTask == nil else { return }
        let taught = state.lesson.steps.compactMap { step -> WordPair? in
            if case .teach(let word) = step { word } else { nil }
        }
        let known = state.lesson.plan.known
        examplesTask = Task { [findExamples] in
            for word in taught {
                do {
                    let sentences = try await findExamples(hanzi: word.hanzi, pinyin: word.pinyin)
                    if let example = sentences.best(teaching: word.hanzi, knowing: known) {
                        state.examples[word.id] = example
                    }
                } catch is CancellationError {
                    return
                } catch {
                    MixedLessonError.findExamplesFailed(VocabularyDomainError(error)).log()
                }
            }
        }
    }

    /// Does nothing when no step has entered it.
    private func leaveRecordingMode() {
        Task { [audioSession] in await audioSession.exitRecordingMode() }
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
