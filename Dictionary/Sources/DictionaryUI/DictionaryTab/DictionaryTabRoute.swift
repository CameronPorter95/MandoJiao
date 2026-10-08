import CoreUI
import DictionaryDomain
import SwiftUI

/// The dictionary on its own, apart from the library: search, then a headword's page, and
/// from there its characters' pages. Any reading can be added to the vocabulary.
public struct DictionaryTabRoute: View {
    @State private var viewModel: DictionarySearchViewModel
    private let makePage: (DictionaryHeadword) -> DictionaryPageViewModel
    private let makeEditor: (ReadingEdit) -> AnyView

    public init(
        viewModel: DictionarySearchViewModel,
        makePage: @escaping (DictionaryHeadword) -> DictionaryPageViewModel,
        makeEditor: @escaping (ReadingEdit) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makePage = makePage
        self.makeEditor = makeEditor
    }

    public var body: some View {
        // The stack is the view model's, so a page pushed by its link and one opened by a
        // driver go the same way.
        NavigationStack(path: Binding(get: { viewModel.state.path }, set: { viewModel.send(.pathChanged($0)) })) {
            DictionarySearchScreen(state: viewModel.state, onAction: { viewModel.send($0) })
                .drivable { viewModel.driver() }
                .sheet(
                    item: Binding(
                        get: { viewModel.state.editor },
                        set: { if $0 == nil { viewModel.send(.editorDismissed) } }
                    )
                ) {
                    makeEditor($0)
                }
                .navigationDestination(for: DictionaryHeadword.self) {
                    DictionaryPage(viewModel: makePage($0), makeEditor: makeEditor, open: { viewModel.send(.opened($0)) })
                }
        }
    }
}
