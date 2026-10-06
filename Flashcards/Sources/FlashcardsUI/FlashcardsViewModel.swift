import CoreDomain
import CoreUI
import FlashcardsDomain
import Foundation
import Observation
import VocabularyDomain

@MainActor
@Observable
public final class FlashcardsViewModel {
    public typealias MakePlan = @MainActor (LessonRequest) -> FlashcardPlan?

    private(set) var state = FlashcardsState()

    private let effectChannel = EffectChannel<FlashcardsEffect>()
    private let request: LessonRequest
    private let recordResults: RecordLessonResultsUseCase
    private let sounds: any MatchSoundPlaying
    private let makePlan: MakePlan
    private var didRecordResults = false

    /// `makePlan` chooses each card's direction and format at random, so tests pass a fixed one.
    public init(
        request: LessonRequest,
        recordResults: RecordLessonResultsUseCase,
        sounds: any MatchSoundPlaying,
        makePlan: @escaping MakePlan = { FlashcardPlanBuilder.makeLesson(title: $0.title, from: $0.pool, otherWords: $0.otherWords) }
    ) {
        self.request = request
        self.recordResults = recordResults
        self.sounds = sounds
        self.makePlan = makePlan
    }

    func effects() -> AsyncStream<FlashcardsEffect> { effectChannel.stream() }

    func send(_ action: FlashcardsAction) {
        switch action {
        case .appeared:
            sounds.prepare()
            if state.lesson == nil { startLesson() }

        case .typedAnswerSubmitted(let text):
            settle(state.lesson?.submit(typed: text))

        case .optionPicked(let id):
            guard case .picked(let options) = state.lesson?.card.format,
                  let option = options.first(where: { $0.id == id })
            else { return }
            settle(state.lesson?.pick(option))

        case .dontKnowTapped:
            // No buzz: giving up is asking for the answer, not getting it wrong.
            state.lesson?.skip()

        case .continueTapped:
            guard let lesson = state.lesson, !lesson.isFinished else { return }
            state.lesson?.advance()
            guard state.lesson?.isFinished == true else { return }
            sounds.playLessonComplete()
            // Recorded as soon as the last card is answered and left, so the review and the
            // mistakes list agree even if the app is killed from here.
            recordResultsOnce()

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

    /// Nil is an answer the card could not take, which gets no verdict. A right answer
    /// plays matching's success tone on one note every time: the owner did not want it to
    /// climb card by card, as a board's does. A wrong one only buzzes.
    private func settle(_ verdict: Bool?) {
        guard let verdict else { return }
        if verdict { sounds.playMatch(step: 0, of: 1) }
        effectChannel.send(.haptic(verdict ? .success : .error))
    }

    private func startLesson() {
        // Practising again starts a fresh tally, so the previous lesson's answers are not
        // written a second time.
        recordResultsOnce()
        didRecordResults = false
        state.lesson = makePlan(request).map(FlashcardLesson.init(plan:))
    }

    private func close() {
        recordResultsOnce()
        effectChannel.send(.close)
    }

    private func recordResultsOnce() {
        guard let lesson = state.lesson, !didRecordResults else { return }
        didRecordResults = true
        let results = LessonResults(
            misses: lesson.missesByPairID,
            cleanSolves: lesson.cleanSolvesByPairID,
            answers: lesson.answers,
            source: request.source
        )

        // Outlives a close on purpose: the lesson has gone, but the results still land.
        Task { [recordResults] in
            do {
                try await recordResults(results)
            } catch is CancellationError {
                // Cancelled, not a failure.
            } catch {
                let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
                let displayError = FlashcardsError.recordResultsFailed(domainError)
                displayError.log()
                effectChannel.send(.showError(displayError))
            }
        }
    }
}
