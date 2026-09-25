import SwiftUI

struct WordLibraryRoute: View {
    @State private var viewModel: WordLibraryViewModel
    private let makeEditor: (Word?) -> WordEditorRoute

    @State private var error: VocabularyError?

    init(viewModel: WordLibraryViewModel, makeEditor: @escaping (Word?) -> WordEditorRoute) {
        _viewModel = State(initialValue: viewModel)
        self.makeEditor = makeEditor
    }

    var body: some View {
        WordLibraryScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .sheet(
                item: Binding(
                    get: { viewModel.state.editor },
                    set: { if $0 == nil { viewModel.send(.editorDismissed) } }
                )
            ) { target in
                makeEditor(target.word)
            }
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects() {
                    switch effect {
                    case .showError(let error): self.error = error
                    }
                }
            }
            .errorAlert($error)
    }
}
