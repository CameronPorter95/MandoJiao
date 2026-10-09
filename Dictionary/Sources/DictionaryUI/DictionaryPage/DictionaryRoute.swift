import CoreUI
import DictionaryDomain
import SwiftUI

/// A sheet of its own, so a character's page can be pushed from any headword's without
/// the presenter's stack knowing about the dictionary.
public struct DictionaryRoute: View {
    private let headword: DictionaryHeadword
    private let makeViewModel: (DictionaryHeadword) -> DictionaryPageViewModel
    private let makeEditor: ((ReadingEdit) -> AnyView)?
    @Environment(\.dismiss) private var dismiss

    /// Without `makeEditor`, as in the word editor's own dictionary, no reading can be
    /// added or opened in the vocabulary.
    public init(
        headword: DictionaryHeadword,
        makeViewModel: @escaping (DictionaryHeadword) -> DictionaryPageViewModel,
        makeEditor: ((ReadingEdit) -> AnyView)?
    ) {
        self.headword = headword
        self.makeViewModel = makeViewModel
        self.makeEditor = makeEditor
    }

    public var body: some View {
        NavigationStack {
            DictionaryPage(viewModel: makeViewModel(headword), makeEditor: makeEditor, open: nil)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: DictionaryHeadword.self) {
                    DictionaryPage(viewModel: makeViewModel($0), makeEditor: makeEditor, open: nil)
                }
        }
    }
}

/// A page with the view model it was made with, for either route's stack.
struct DictionaryPage: View {
    @State private var viewModel: DictionaryPageViewModel
    private let makeEditor: ((ReadingEdit) -> AnyView)?
    private let open: ((DictionaryHeadword) -> Void)?

    /// `open` pushes a character's page, for a driver; nil where the stack is the view's own.
    init(viewModel: DictionaryPageViewModel, makeEditor: ((ReadingEdit) -> AnyView)?, open: ((DictionaryHeadword) -> Void)?) {
        _viewModel = State(initialValue: viewModel)
        self.makeEditor = makeEditor
        self.open = open
    }

    var body: some View {
        DictionaryPageScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .drivable { viewModel.driver(open: open) }
            .sheet(
                item: Binding(
                    get: { viewModel.state.editor },
                    set: { if $0 == nil { viewModel.send(.editorDismissed) } }
                )
            ) { target in
                makeEditor?(target)
            }
    }
}
