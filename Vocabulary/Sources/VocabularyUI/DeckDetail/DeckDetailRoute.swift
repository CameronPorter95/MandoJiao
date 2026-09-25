import CoreUI
import SwiftUI

public struct DeckDetailRoute: View {
    @State private var viewModel: DeckDetailViewModel
    private let navigation: DeckDetailNavigation

    @Environment(\.dismiss) private var dismiss
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
                        navigation.didRequestMatching(request)
                        dismiss()
                    case .showError(let error):
                        self.error = error
                    }
                }
            }
            .errorAlert($error)
    }
}
