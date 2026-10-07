import CoreDomain
import LibraryDomain
import Observation
import PracticeDomain
import SwiftUI

/// One matching board as a step of a longer lesson: the board, its tones and haptics, and its
/// answers handed back a moment after it is cleared. The lesson around it records and
/// summarises.
public struct MatchingStepRoute: View {
    @State private var viewModel: MatchingStepViewModel
    @State private var haptic: StepHaptic?

    public init(viewModel: MatchingStepViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack {
            Text("Match each pair")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            Spacer(minLength: 0)
            MatchingBoardView(board: viewModel.lesson.board, showsPinyin: viewModel.showsPinyin) { tile in
                haptic = viewModel.tap(tile).map { StepHaptic(kind: $0) } ?? haptic
            }
            Spacer(minLength: 0)
        }
        .onAppear { viewModel.appeared() }
        .sensoryFeedback(trigger: haptic) { _, event in
            switch event?.kind {
            case .success: .success
            case .match: .impact(weight: .light)
            case .miss: .error
            case .selection: .selection
            case .none: nil
            }
        }
    }
}

/// Unique per tap, so two identical taps in a row still fire twice.
private struct StepHaptic: Equatable {
    let id = UUID()
    let kind: MatchingHaptic
}

@MainActor
@Observable
public final class MatchingStepViewModel {
    private(set) var lesson: MatchingLesson
    let showsPinyin: Bool

    private let sounds: any MatchSoundPlaying
    private let advanceDelay: Duration
    private let onComplete: ([Answer]) -> Void
    private var isFinished = false

    /// `pairs` are one board's. `onComplete` hands back its answers, once.
    public init(
        pairs: [WordPair],
        showsPinyin: Bool,
        sounds: any MatchSoundPlaying,
        advanceDelay: Duration = .milliseconds(320),
        onComplete: @escaping ([Answer]) -> Void
    ) {
        lesson = MatchingLesson(plan: MatchingPlan(title: "", exercises: [pairs]))
        self.showsPinyin = showsPinyin
        self.sounds = sounds
        self.advanceDelay = advanceDelay
        self.onComplete = onComplete
    }

    func appeared() {
        sounds.prepare()
    }

    /// The haptic a tap earns, as the matching lesson gives them, nil for none.
    func tap(_ tile: Tile) -> MatchingHaptic? {
        let result = lesson.tap(tile)
        switch result {
        case .matched(let step, let boardComplete, _):
            sounds.playMatch(step: step, of: lesson.board.pairs.count)
            if boardComplete { finish() }
            return boardComplete ? .success : .match
        case .missed:
            sounds.playMiss()
            return .miss
        case .selected, .switched:
            return .selection
        case .deselected, .ignored:
            return nil
        }
    }

    /// After the board's own pause, so the last match is seen before the next step.
    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        let answers = lesson.answers
        Task { [advanceDelay, onComplete] in
            try? await Task.sleep(for: advanceDelay)
            onComplete(answers)
        }
    }
}
