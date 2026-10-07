import CoreUI
import SwiftUI

public struct HomeRoute: View {
    @State private var viewModel: HomeViewModel
    private let navigation: HomeNavigation
    private let destination: (HomeDestination) -> AnyView

    @State private var error: VocabularyError?

    public init(
        viewModel: HomeViewModel,
        navigation: HomeNavigation,
        destination: @escaping (HomeDestination) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.destination = destination
    }

    public var body: some View {
        HomeScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .navigationDestination(for: HomeDestination.self) { destination($0) }
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects() {
                    handle(effect)
                }
            }
            .errorAlert($error)
    }

    private func handle(_ effect: HomeEffect) {
        switch effect {
        case .requestMatching(let request): navigation.didRequestMatching(request)
        case .requestSpeaking(let request): navigation.didRequestSpeaking(request)
        case .requestFlashcards(let request): navigation.didRequestFlashcards(request)
        case .requestTodayPlan(let plan): navigation.didRequestTodayPlan(plan)
        case .showError(let error): self.error = error
        }
    }
}
