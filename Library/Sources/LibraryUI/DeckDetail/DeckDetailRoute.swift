import CoreUI
import SwiftUI

public struct DeckDetailRoute: View {
    @State private var viewModel: DeckDetailViewModel
    private let navigation: DeckDetailNavigation

    @State private var error: VocabularyError?

    public init(viewModel: DeckDetailViewModel, navigation: DeckDetailNavigation) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
    }

    public var body: some View {
        DeckDetailScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .drivable { viewModel.driver(navigation: navigation) }
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects() {
                    // A lesson is presented over the deck, which stays pushed, so closing it
                    // comes back here rather than to home.
                    if case .showError(let error) = navigation.follow(effect) {
                        self.error = error
                    }
                }
            }
            .errorAlert($error)
    }
}
