import CoreUI
import SwiftUI
import VocabularyDomain

public struct WordLibraryRoute: View {
    @State private var viewModel: WordLibraryViewModel
    private let makeEditor: (Word?) -> WordEditorRoute
    private let makeDictionary: (DictionaryHeadword) -> DictionaryRoute

    @State private var error: VocabularyError?

    public init(
        viewModel: WordLibraryViewModel,
        makeEditor: @escaping (Word?) -> WordEditorRoute,
        makeDictionary: @escaping (DictionaryHeadword) -> DictionaryRoute
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeEditor = makeEditor
        self.makeDictionary = makeDictionary
    }

    public var body: some View {
        WordLibraryScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .sheet(
                item: Binding(
                    get: { viewModel.state.editor },
                    set: { if $0 == nil { viewModel.send(.editorDismissed) } }
                )
            ) { target in
                makeEditor(target.word)
            }
            .sheet(
                item: Binding(
                    get: { viewModel.state.dictionary },
                    set: { if $0 == nil { viewModel.send(.dictionaryDismissed) } }
                )
            ) {
                makeDictionary($0)
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
