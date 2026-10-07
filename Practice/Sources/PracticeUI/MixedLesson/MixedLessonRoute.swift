import CoreUI
import LibraryDomain
import PracticeDomain
import SwiftUI

/// Owns the mixed lesson's view model, carries out its effects, and shows each exercise step
/// as its factory builds it.
public struct MixedLessonRoute: View {
    @State private var viewModel: MixedLessonViewModel
    private let navigation: MixedLessonNavigation
    private let makeStep: (MixedStep, @escaping ([Answer]) -> Void) -> AnyView

    @State private var error: MixedLessonError?

    /// `makeStep` builds a matching board or flash card step, calling back with its answers.
    public init(
        viewModel: MixedLessonViewModel,
        navigation: MixedLessonNavigation,
        makeStep: @escaping (MixedStep, @escaping ([Answer]) -> Void) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.makeStep = makeStep
    }

    public var body: some View {
        MixedLessonScreen(
            state: viewModel.state,
            onAction: { viewModel.send($0) },
            step: { step in makeStep(step) { viewModel.send(.stepCompleted($0)) } }
        )
        .task {
            for await effect in viewModel.effects() {
                switch effect {
                case .showError(let error): self.error = error
                case .close: navigation.didClose()
                }
            }
        }
        .errorAlert($error)
    }
}
