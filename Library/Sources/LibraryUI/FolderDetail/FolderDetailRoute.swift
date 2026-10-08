import CoreUI
import SwiftUI

public struct FolderDetailRoute: View {
    @State private var viewModel: FolderDetailViewModel
    private let navigation: FolderDetailNavigation
    private let layout: FolderLayout
    private let results: (String) -> WordLibraryRoute

    @State private var error: VocabularyError?

    /// `results` builds the words found by the folder's search, for what has been typed.
    public init(
        viewModel: FolderDetailViewModel,
        navigation: FolderDetailNavigation,
        layout: FolderLayout,
        results: @escaping (String) -> WordLibraryRoute
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.layout = layout
        self.results = results
    }

    public var body: some View {
        FolderDetailScreen(
            state: viewModel.state,
            layout: layout,
            onAction: { viewModel.send($0) },
            results: { AnyView(results($0)) }
        )
        .onAppear { viewModel.send(.appeared) }
        .onDisappear { viewModel.send(.disappeared) }
        .task {
            for await effect in viewModel.effects() {
                if case .showError(let error) = navigation.follow(effect) {
                    self.error = error
                }
            }
        }
        .errorAlert($error)
    }
}
