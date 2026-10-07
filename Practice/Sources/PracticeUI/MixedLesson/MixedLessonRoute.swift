import CoreUI
import LibraryDomain
import PracticeDomain
import SwiftUI

/// Owns the mixed lesson's view model, carries out its effects, and shows each exercise step
/// as its factory builds it.
public struct MixedLessonRoute: View {
    @State private var viewModel: MixedLessonViewModel
    private let navigation: MixedLessonNavigation
    private let makeStep: (MixedStep, _ listensAtOnce: Bool, @escaping MixedLessonRoute.StepCompletion) -> AnyView

    @State private var error: MixedLessonError?

    /// A step's answers, and for a read-aloud step whether a next one should listen at once.
    public typealias StepCompletion = (_ answers: [Answer], _ carriesOn: Bool) -> Void

    /// `makeStep` builds a matching board, flash card or read-aloud step, calling back with
    /// its answers. `listensAtOnce` tells a read-aloud step to start listening by itself.
    public init(
        viewModel: MixedLessonViewModel,
        navigation: MixedLessonNavigation,
        makeStep: @escaping (MixedStep, _ listensAtOnce: Bool, @escaping StepCompletion) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.makeStep = makeStep
    }

    public var body: some View {
        MixedLessonScreen(
            state: viewModel.state,
            onAction: { viewModel.send($0) },
            step: { step in
                makeStep(step, viewModel.state.lesson.listensOnArrival) { viewModel.send(.stepCompleted($0, carriesOn: $1)) }
            }
        )
        .onDisappear { viewModel.send(.disappeared) }
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
