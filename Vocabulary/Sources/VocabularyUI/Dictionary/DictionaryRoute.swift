import SwiftUI

/// A sheet of its own, so a character's page can be pushed from any headword's without
/// the presenter's stack knowing about the dictionary.
public struct DictionaryRoute: View {
    private let headword: DictionaryHeadword
    private let makeViewModel: (DictionaryHeadword) -> DictionaryPageViewModel
    @Environment(\.dismiss) private var dismiss

    public init(headword: DictionaryHeadword, makeViewModel: @escaping (DictionaryHeadword) -> DictionaryPageViewModel) {
        self.headword = headword
        self.makeViewModel = makeViewModel
    }

    public var body: some View {
        NavigationStack {
            DictionaryPage(viewModel: makeViewModel(headword))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: DictionaryHeadword.self) {
                    DictionaryPage(viewModel: makeViewModel($0))
                }
        }
    }
}

private struct DictionaryPage: View {
    @State private var viewModel: DictionaryPageViewModel

    init(viewModel: DictionaryPageViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        DictionaryPageScreen(state: viewModel.state, onAction: { viewModel.send($0) })
    }
}
