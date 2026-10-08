import CoreUI
import SwiftUI

/// Owns the matching lesson's view model and carries out its effects.
public struct MatchingRoute: View {
    @State private var viewModel: MatchingViewModel
    private let navigation: MatchingNavigation

    @State private var haptic: HapticEvent?
    @State private var error: MatchingError?

    public init(viewModel: MatchingViewModel, navigation: MatchingNavigation) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
    }

    public var body: some View {
        MatchingScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .drivable { viewModel.driver(navigation: navigation) }
            .onAppear { viewModel.send(.appeared) }
            .task {
                for await effect in viewModel.effects() {
                    handle(effect)
                }
            }
            .sensoryFeedback(trigger: haptic) { _, event in
                switch event?.kind {
                case .success: .success
                case .match: .impact(weight: .light)
                case .miss: .error
                case .selection: .selection
                case .none: nil
                }
            }
            .errorAlert($error)
    }

    private func handle(_ effect: MatchingEffect) {
        switch navigation.follow(effect) {
        case .haptic(let kind): haptic = HapticEvent(kind: kind)
        case .showError(let error): self.error = error
        case .close, nil: break
        }
    }
}

/// Unique per tap, so two identical taps in a row still fire twice.
private struct HapticEvent: Equatable {
    let id = UUID()
    let kind: MatchingHaptic
}
