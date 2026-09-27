import CoreUI
import SwiftUI

public struct FolderDetailRoute: View {
    @State private var viewModel: FolderDetailViewModel
    private let navigation: FolderDetailNavigation

    @State private var error: VocabularyError?

    public init(viewModel: FolderDetailViewModel, navigation: FolderDetailNavigation) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
    }

    public var body: some View {
        FolderDetailScreen(
            state: viewModel.state,
            onAction: { viewModel.send($0) },
            onOpenDeck: { navigation.didOpenDeck($0) },
            onOpenFolder: { navigation.didOpenFolder($0) }
        )
        .onAppear { viewModel.send(.appeared) }
        .onDisappear { viewModel.send(.disappeared) }
        .task {
            for await effect in viewModel.effects() {
                switch effect {
                case .startLesson(let request):
                    navigation.didRequestMatching(request)
                case .showError(let error):
                    self.error = error
                }
            }
        }
        .errorAlert($error)
    }
}
