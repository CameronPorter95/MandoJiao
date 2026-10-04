import CoreDomain
import CoreUI
import Foundation
import Observation
import SpeakingDomain
import VocabularyDomain

/// Runs a speaking lesson: the cards, the microphone, and writing results back.
///
/// Everything platform-bound arrives through a seam, so the whole speaking lesson, microphone
/// rules included, can be driven by a scripted recogniser with no audio hardware.
@MainActor
@Observable
public final class SpeakingViewModel {
    public typealias WaitForEnd = @MainActor (_ transcript: () -> String) async -> Endpointing.Ending
    public typealias LogAttempt = @MainActor (SpeechAttempt) -> Void

    private(set) var state = SpeakingState()

    private let effectChannel = EffectChannel<SpeakingEffect>()

    private let request: LessonRequest
    private let recogniser: any SpeechRecognising
    private let audioSession: any AudioSessionSwitching
    private let sounds: any MatchSoundPlaying
    private let getSettings: GetSpeakingSettingsUseCase
    private let recordResults: RecordLessonResultsUseCase
    private let logAttempt: LogAttempt
    private let advanceDelay: Duration
    private let waitForEnd: WaitForEnd

    private var didRecordResults = false
    private var prepareTask: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    public init(
        request: LessonRequest,
        recogniser: any SpeechRecognising,
        audioSession: any AudioSessionSwitching,
        sounds: any MatchSoundPlaying,
        getSettings: GetSpeakingSettingsUseCase,
        recordResults: RecordLessonResultsUseCase,
        logAttempt: @escaping LogAttempt,
        advanceDelay: Duration = .milliseconds(850),
        waitForEnd: @escaping WaitForEnd = { await Endpointing.waitForEnd(transcript: $0) }
    ) {
        self.request = request
        self.recogniser = recogniser
        self.audioSession = audioSession
        self.sounds = sounds
        self.getSettings = getSettings
        self.recordResults = recordResults
        self.logAttempt = logAttempt
        self.advanceDelay = advanceDelay
        self.waitForEnd = waitForEnd
    }

    func effects() -> AsyncStream<SpeakingEffect> { effectChannel.stream() }

    func send(_ action: SpeakingAction) {
        switch action {
        case .appeared:
            prepareTask = Task { await prepare() }

        case .disappeared:
            prepareTask?.cancel()
            listeningTask?.cancel()
            advanceTask?.cancel()
            recogniser.cancel()
            Task { await audioSession.exitRecordingMode() }

        case .sceneLeftForeground:
            // Losing the foreground mid-answer would otherwise leave the tap installed.
            stopListening(submitting: false)

        case .startListeningTapped:
            startListening(automatic: false)

        case .stopListeningTapped:
            stopListening(submitting: true)

        case .typedAnswerSubmitted(let answer):
            guard SpeakingLesson.canSubmitTyped(answer) else { return }
            submit(SpeechOutcome(best: answer))

        case .typingToggled:
            state.prefersTyping.toggle()

        case .continueTapped:
            advance()

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

    // MARK: - Preparing

    private func prepare() async {
        if state.lesson == nil { startLesson() }
        mirrorRecogniser()

        let availability = await recogniser.prepare()
        if availability.canListen {
            audioSession.enterRecordingMode()
        } else {
            // Fall straight into typing rather than showing a mic that cannot work.
            state.prefersTyping = true
        }
    }

    /// Copies the recogniser's live values into state for as long as they keep changing.
    private func mirrorRecogniser() {
        let (availability, partialText) = withObservationTracking {
            (recogniser.availability, recogniser.partialText)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.mirrorRecogniser() }
        }
        if state.availability != availability { state.availability = availability }
        if state.partialText != partialText { state.partialText = partialText }
    }

    // MARK: - Microphone

    /// `automatic` marks a listen the speaking lesson started itself, carrying on from a correct
    /// answer rather than following a tap.
    private func startListening(automatic: Bool) {
        guard state.mic == .idle,
              recogniser.availability.canListen,
              let lesson = state.lesson,
              !lesson.isFinished
        else { return }

        // Drop the previous failure before listening, or it stays on screen instead of
        // this attempt's transcript.
        state.lesson?.beginAttempt()

        // Arming, not listening: opening the microphone takes a moment, and saying
        // "listening" through it would invite talking into a microphone that is not
        // recording yet.
        state.mic = .arming

        let hints = [lesson.card.hanzi, lesson.card.pinyin].filter { !$0.isEmpty }
        listeningTask = Task { await listen(hints: hints, automatic: automatic) }
    }

    private func listen(hints: [String], automatic: Bool) async {
        // The previous teardown nils the analyser once it has finished finalising, so
        // starting on top of it would leave the new session with its state pulled out
        // from under it.
        await stopTask?.value
        guard !Task.isCancelled else {
            state.mic = .idle
            return
        }

        do {
            try await recogniser.start(hints: hints)
        } catch {
            state.mic = .idle
            return
        }
        guard !Task.isCancelled else { return }
        state.mic = .listening

        // Stops as soon as the transcript stops moving, rather than waiting out the limit
        // on every card.
        let recogniser = recogniser
        let ending = await waitForEnd { recogniser.partialText }
        guard !Task.isCancelled else { return }

        // A listen the speaking lesson started can open before the word has even been read, so
        // hearing nothing means "not ready yet" rather than a failed attempt. A tap is a
        // deliberate go, and silence after one still counts.
        let heardNothing = ending == .reachedLimit && recogniser.partialText.isEmpty
        stopListening(submitting: !(automatic && heardNothing))
    }

    private func stopListening(submitting: Bool) {
        guard state.mic != .idle else { return }
        state.mic = .idle
        listeningTask?.cancel()
        listeningTask = nil

        stopTask = Task {
            let outcome = await recogniser.stop()
            if submitting { submit(outcome) }
        }
    }

    // MARK: - Cards

    private func submit(_ outcome: SpeechOutcome) {
        guard let card = state.lesson?.card,
              let isRight = state.lesson?.submit(outcome),
              let lesson = state.lesson
        else { return }

        logAttempt(SpeechAttempt(
            card: card,
            outcome: outcome,
            strictness: lesson.strictness,
            attempt: lesson.attemptsUsed,
            totalAttempts: SpeakingPlanBuilder.attemptsPerCard,
            wasCorrect: isRight
        ))

        // No per-card tone. Under the microphone's measurement mode it would play markedly
        // quieter than a matching lesson's, so haptics carry the verdict instead.
        effectChannel.send(.haptic(isRight ? .success : .error))

        if isRight { scheduleAdvance() }
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
        // Cancels any pending auto-advance, so advancing by hand cannot land twice.
        advanceTask?.cancel()
        advanceTask = nil

        state.lesson?.advance()
        guard let lesson = state.lesson else { return }

        if lesson.isFinished {
            finish()
        } else if lesson.advancedAfterCorrect, !state.prefersTyping {
            // Carries straight on to the next word after a correct answer, so a run of
            // them needs one tap rather than one per card. Started on the card changing
            // rather than on the answer landing, so the microphone is closed during the
            // pause between the two.
            startListening(automatic: true)
        }
    }

    private func finish() {
        recordResultsOnce()

        // Nothing else needs the microphone now. Handing the session back before the
        // fanfare is what lets it be heard at the same level as everywhere else.
        Task {
            await audioSession.exitRecordingMode()
            sounds.playLessonComplete()
        }
    }

    // MARK: - Lesson

    private func startLesson() {
        recordResultsOnce()
        didRecordResults = false
        advanceTask?.cancel()
        advanceTask = nil

        let settings = getSettings()
        guard let plan = SpeakingPlanBuilder.makeLesson(
            title: request.title,
            from: request.pool,
            maxCards: settings.cardLimit
        ) else {
            state.lesson = nil
            return
        }

        // Practising again after finishing needs the microphone session back, since
        // finishing handed it over so the fanfare could be heard properly.
        if recogniser.availability.canListen {
            audioSession.enterRecordingMode()
        }
        state.lesson = SpeakingLesson(plan: plan, strictness: settings.strictness)
    }

    private func close() {
        stopListening(submitting: false)
        recordResultsOnce()
        effectChannel.send(.close)
    }

    private func recordResultsOnce() {
        guard let lesson = state.lesson, !didRecordResults else { return }
        didRecordResults = true
        let results = LessonResults(misses: lesson.missesByPairID, cleanSolves: lesson.cleanSolvesByPairID, answers: lesson.answers)

        // Outlives a close on purpose: the speaking lesson has gone, but the results still land.
        Task { [recordResults] in
            do {
                try await recordResults(results)
            } catch is CancellationError {
                // Cancelled, not a failure.
            } catch {
                let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                let displayError = SpeakingError.recordResultsFailed(domainError)
                displayError.log()
                effectChannel.send(.showError(displayError))
            }
        }
    }
}
