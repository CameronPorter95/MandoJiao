import CoreUI
import SwiftUI

/// Owns the speaking lesson's view model and carries out its effects.
public struct SpeakingRoute: View {
    @State private var viewModel: SpeakingViewModel
    private let navigation: SpeakingNavigation

    @Environment(\.scenePhase) private var scenePhase
    @State private var haptic: HapticEvent?
    @State private var error: SpeakingError?

    public init(viewModel: SpeakingViewModel, navigation: SpeakingNavigation) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
    }

    public var body: some View {
        SpeakingScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects() {
                    handle(effect)
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
            .errorAlert($error)
    }

    private func handle(_ effect: SpeakingEffect) {
        switch navigation.follow(effect) {
        case .haptic(let kind):
            haptic = HapticEvent(kind: kind)
        case .showError(let error):
            self.error = error
        case .close, nil:
            break
        }
    }
}

/// Unique per verdict, so two identical verdicts in a row still fire twice.
private struct HapticEvent: Equatable {
    let id = UUID()
    let kind: SpeakingHaptic
}
