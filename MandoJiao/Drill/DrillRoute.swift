import SwiftUI

/// Owns the drill's view model and carries out its effects.
struct DrillRoute: View {
    @State private var viewModel: DrillViewModel
    private let navigation: DrillNavigation

    @Environment(\.scenePhase) private var scenePhase
    @State private var haptic: HapticEvent?

    init(viewModel: DrillViewModel, navigation: DrillNavigation) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
    }

    var body: some View {
        DrillScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects {
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
    }

    private func handle(_ effect: DrillEffect) {
        switch effect {
        case .haptic(let kind):
            haptic = HapticEvent(kind: kind)
        case .close:
            navigation.didClose()
        }
    }
}

/// Unique per verdict, so two identical verdicts in a row still fire twice.
private struct HapticEvent: Equatable {
    let id = UUID()
    let kind: DrillHaptic
}
