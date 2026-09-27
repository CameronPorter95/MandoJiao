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
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects() {
                    switch effect {
                    case .startLesson(let request):
                        // Stays pushed: the lesson is presented over the deck, and closing
                        // it comes back here rather than to home.
                        navigation.didRequestMatching(request)
                    case .showError(let error):
                        self.error = error
                    }
                }
            }
            .errorAlert($error)
    }
}
