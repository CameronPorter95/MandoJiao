import CoreUI
import SwiftUI

/// One word read aloud as a step of a longer lesson: the speaking lesson's card, microphone
/// and three tries, with its answer handed back once the card settles. The lesson around it
/// records, summarises and owns the audio session between steps.
public struct SpeakingStepRoute: View {
    @State private var viewModel: SpeakingViewModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var haptic: HapticEvent?

    /// `viewModel` is made with `.step` completion.
    public init(viewModel: SpeakingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        let state = viewModel.state
        VStack(alignment: .leading, spacing: 0) {
            if let notice = state.availabilityNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let lesson = state.lesson {
                SpeakingCardView(
                    card: lesson.card,
                    phase: lesson.phase,
                    attemptsLeft: lesson.attemptsLeft,
                    micState: state.mic,
                    partialText: state.partialText,
                    isTyping: state.isTyping,
                    canListen: state.availability.canListen,
                    onStartListening: { viewModel.send(.startListeningTapped) },
                    onStopListening: { viewModel.send(.stopListeningTapped) },
                    onSubmitTyped: { viewModel.send(.typedAnswerSubmitted(answer: $0)) },
                    onToggleTyping: { viewModel.send(.typingToggled) },
                    onContinue: { viewModel.send(.continueTapped) }
                )
            }
        }
        // A step is closed by the lesson around it, never by itself.
        .drivable { viewModel.driver(navigation: SpeakingNavigation(didClose: {})) }
        .onAppear { viewModel.send(.appeared) }
        .onDisappear { viewModel.send(.disappeared) }
        .task {
            for await effect in viewModel.effects() {
                // A step neither closes nor records, so the verdict's haptic is all it hears.
                if case .haptic(let kind) = effect { haptic = HapticEvent(kind: kind) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.send(.sceneLeftForeground) }
        }
        .sensoryFeedback(trigger: haptic) { _, event in
            switch event?.kind {
            case .success: return .success
            case .error: return .error
            case .none: return nil
            }
        }
    }
}

/// Unique per verdict, so two identical verdicts in a row still fire twice.
private struct HapticEvent: Equatable {
    let id = UUID()
    let kind: SpeakingHaptic
}
