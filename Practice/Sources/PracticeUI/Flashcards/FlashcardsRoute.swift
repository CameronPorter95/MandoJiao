import CoreUI
import SwiftUI

/// Owns the flash card lesson's view model and carries out its effects.
public struct FlashcardsRoute: View {
    @State private var viewModel: FlashcardsViewModel
    private let navigation: FlashcardsNavigation

    @State private var haptic: HapticEvent?
    @State private var error: FlashcardsError?

    public init(viewModel: FlashcardsViewModel, navigation: FlashcardsNavigation) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
    }

    public var body: some View {
        FlashcardsScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .onAppear { viewModel.send(.appeared) }
            .task {
                for await effect in viewModel.effects() {
                    switch effect {
                    case .haptic(let kind): haptic = HapticEvent(kind: kind)
                    case .showError(let error): self.error = error
                    case .close: navigation.didClose()
                    }
                }
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
}

/// Unique per verdict, so two identical verdicts in a row still fire twice.
private struct HapticEvent: Equatable {
    let id = UUID()
    let kind: FlashcardsHaptic
}
