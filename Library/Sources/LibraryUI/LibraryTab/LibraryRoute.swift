import CoreUI
import SwiftUI

/// The sidebar beside a stack: what it has open, then folders and decks pushed over that.
/// On iPhone the two collapse into one push stack.
///
/// Two columns, not three. With a third, the middle column's screen was sent a disappear on
/// iPhone while still showing, which ended its effects loop and live data.
public struct LibraryRoute: View {
    @State private var viewModel: LibraryViewModel
    private let navigation: LibraryTabNavigation
    private let root: (LibrarySelection, LibraryPageContext) -> AnyView
    private let page: (LibraryPage, LibraryPageContext) -> AnyView
    private let results: (String, LibraryPageContext) -> AnyView
    private let makeEditor: (WordEditorTarget) -> WordEditorRoute
    private let hskLevels: () -> AnyView

    @State private var error: VocabularyError?
    /// Not derived from the selection: popping the stack to its first screen reports `.sidebar`.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    /// `root` builds what the sidebar selects, `page` what is pushed over it, and `results`
    /// the words found by the sidebar's search, for what has been typed.
    public init(
        viewModel: LibraryViewModel,
        navigation: LibraryTabNavigation,
        root: @escaping (LibrarySelection, LibraryPageContext) -> AnyView,
        page: @escaping (LibraryPage, LibraryPageContext) -> AnyView,
        results: @escaping (String, LibraryPageContext) -> AnyView,
        makeEditor: @escaping (WordEditorTarget) -> WordEditorRoute,
        hskLevels: @escaping () -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.root = root
        self.page = page
        self.results = results
        self.makeEditor = makeEditor
        self.hskLevels = hskLevels
    }

    public var body: some View {
        let state = viewModel.state
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            LibrarySidebar(state: state, results: { results($0, pageContext) }, onAction: { action in
                viewModel.send(action)
                if case .selected(.some) = action { compactColumn = .detail }
            })
        } detail: {
            NavigationStack(path: Binding(get: { viewModel.state.path }, set: { viewModel.send(.pathChanged($0)) })) {
                Group {
                    if let selection = state.selection {
                        root(selection, pageContext).id(selection)
                    } else {
                        ContentUnavailableView("Choose a folder", systemImage: "folder")
                    }
                }
                .navigationDestination(for: LibraryPage.self) { page($0, pageContext) }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.isShowingHSKLevels },
            set: { if !$0 { viewModel.send(.hskLevelsDismissed) } }
        )) {
            hskLevels()
        }
        .sheet(item: Binding(
            get: { viewModel.state.editor },
            set: { if $0 == nil { viewModel.send(.editorDismissed) } }
        )) {
            makeEditor($0)
        }
        .onAppear { viewModel.send(.appeared) }
        .onDisappear { viewModel.send(.disappeared) }
        .task {
            for await effect in viewModel.effects() {
                if case .showError(let error) = navigation.follow(effect) { self.error = error }
            }
        }
        .errorAlert($error)
    }

    private var pageContext: LibraryPageContext { viewModel.pageContext }
}
