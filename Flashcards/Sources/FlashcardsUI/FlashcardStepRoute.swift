import CoreDomain
import FlashcardsDomain
import Observation
import SwiftUI
import VocabularyDomain

/// One flash card as a step of a longer lesson: the card, its verdict and tone, and its
/// answer handed back on Continue. The lesson around it records and summarises.
public struct FlashcardStepRoute: View {
    @State private var viewModel: FlashcardStepViewModel
    @State private var haptic: HapticEvent?

    public init(viewModel: FlashcardStepViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        FlashcardView(
            card: viewModel.lesson.card,
            phase: viewModel.lesson.phase,
            onSubmitTyped: { haptic = viewModel.submit(typed: $0).map(HapticEvent.init) ?? haptic },
            onPick: { haptic = viewModel.pick($0).map(HapticEvent.init) ?? haptic },
            onDontKnow: { viewModel.dontKnow() },
            onContinue: { viewModel.finish() }
        )
        .onAppear { viewModel.appeared() }
        .sensoryFeedback(trigger: haptic) { _, event in
            switch event?.isRight {
            case true: return .success
            case false: return .error
            case nil: return nil
            }
        }
    }
}

/// Unique per verdict, so two identical verdicts in a row still fire twice.
private struct HapticEvent: Equatable {
    let id = UUID()
    let isRight: Bool
}

@MainActor
@Observable
public final class FlashcardStepViewModel {
    private(set) var lesson: FlashcardLesson

    private let sounds: any MatchSoundPlaying
    private let onComplete: ([Answer]) -> Void
    private var isFinished = false

    /// `onComplete` hands back the card's answer, once.
    public init(card: Flashcard, sounds: any MatchSoundPlaying, onComplete: @escaping ([Answer]) -> Void) {
        lesson = FlashcardLesson(plan: FlashcardPlan(title: "", cards: [card]))
        self.sounds = sounds
        self.onComplete = onComplete
    }

    func appeared() {
        sounds.prepare()
    }

    /// The verdict, nil when the text could not be checked.
    func submit(typed text: String) -> Bool? {
        settle(lesson.submit(typed: text))
    }

    func pick(_ id: UUID) -> Bool? {
        guard case .picked(let options) = lesson.card.format, let option = options.first(where: { $0.id == id }) else { return nil }
        return settle(lesson.pick(option))
    }

    func dontKnow() {
        lesson.skip()
    }

    func finish() {
        guard !isFinished, lesson.phase != .answering else { return }
        isFinished = true
        onComplete(lesson.answers)
    }

    /// The same one note as the flash card lesson's, on a right answer.
    private func settle(_ verdict: Bool?) -> Bool? {
        if verdict == true { sounds.playMatch(step: 0, of: 1) }
        return verdict
    }
}
