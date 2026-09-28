import SwiftUI

/// The dictionary on its own, apart from the library: search, then a headword's page, and
/// from there its characters' pages.
public struct DictionaryTabRoute: View {
    @State private var viewModel: DictionarySearchViewModel
    private let makePage: (DictionaryHeadword) -> DictionaryPageViewModel

    public init(viewModel: DictionarySearchViewModel, makePage: @escaping (DictionaryHeadword) -> DictionaryPageViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.makePage = makePage
    }

    public var body: some View {
        NavigationStack {
            DictionarySearchScreen(state: viewModel.state, onAction: { viewModel.send($0) })
                .navigationDestination(for: DictionaryHeadword.self) {
                    DictionaryPage(viewModel: makePage($0))
                }
        }
    }
}
