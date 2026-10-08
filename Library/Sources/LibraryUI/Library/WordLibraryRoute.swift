import CoreUI
import DictionaryDomain
import LibraryDomain
import SwiftUI

/// The results of a search, shown by the screen searched in place of its own content.
public struct WordLibraryRoute: View {
    @State private var viewModel: WordLibraryViewModel
    private let makeEditor: (WordEditorTarget) -> WordEditorRoute
    private let makeDictionary: (DictionaryHeadword) -> AnyView
    private let layout: WordListLayout
    private let searchText: String

    @State private var error: VocabularyError?

    /// `searchText` is the screen searched's, handed on as it changes.
    public init(
        viewModel: WordLibraryViewModel,
        layout: WordListLayout,
        searchText: String,
        makeEditor: @escaping (WordEditorTarget) -> WordEditorRoute,
        makeDictionary: @escaping (DictionaryHeadword) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.layout = layout
        self.searchText = searchText
        self.makeEditor = makeEditor
        self.makeDictionary = makeDictionary
    }

    public var body: some View {
        WordLibraryScreen(state: viewModel.state, layout: layout, onAction: { viewModel.send($0) })
            .sheet(
                item: Binding(
                    get: { viewModel.state.editor },
                    set: { if $0 == nil { viewModel.send(.editorDismissed) } }
                )
            ) { target in
                makeEditor(target)
            }
            .sheet(
                item: Binding(
                    get: { viewModel.state.dictionary },
                    set: { if $0 == nil { viewModel.send(.dictionaryDismissed) } }
                )
            ) {
                makeDictionary($0)
            }
            .onChange(of: layout.sort) { _, sort in viewModel.send(.sortChanged(sort)) }
            .onChange(of: searchText) { _, text in viewModel.send(.searchChanged(text)) }
            .drivable { viewModel.driver(layout: layout) }
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
