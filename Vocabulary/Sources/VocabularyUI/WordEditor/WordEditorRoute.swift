import CoreUI
import SwiftUI

public struct WordEditorRoute: View {
    @State private var viewModel: WordEditorViewModel
    private let makeDictionary: (DictionaryHeadword) -> DictionaryRoute
    @Environment(\.dismiss) private var dismiss
    @State private var error: VocabularyError?

    public init(viewModel: WordEditorViewModel, makeDictionary: @escaping (DictionaryHeadword) -> DictionaryRoute) {
        _viewModel = State(initialValue: viewModel)
        self.makeDictionary = makeDictionary
    }

    public var body: some View {
        WordEditorScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .sheet(
                item: Binding(
                    get: { viewModel.state.dictionary },
                    set: { if $0 == nil { viewModel.send(.dictionaryDismissed) } }
                )
            ) {
                makeDictionary($0)
            }
            .task {
                for await effect in viewModel.effects() {
                    switch effect {
                    case .dismiss: dismiss()
                    case .showError(let error): self.error = error
                    }
                }
            }
            .onAppear { viewModel.send(.appeared) }
            .errorAlert($error)
    }
}
