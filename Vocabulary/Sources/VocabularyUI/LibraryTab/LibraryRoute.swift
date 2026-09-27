import CoreUI
import SwiftUI

/// The sidebar beside a stack: what it has open, then folders and decks pushed over that.
/// On iPhone the two collapse into one push stack.
///
/// Two columns, not three. With a third, the middle column's screen was sent a disappear on
/// iPhone while still showing, which ended its effects loop and live data.
public struct LibraryRoute: View {
    @State private var viewModel: LibraryViewModel
    private let navigation: LibraryNavigation
    private let root: (LibrarySelection, LibraryColumnNavigation) -> AnyView
    private let page: (LibraryPage, LibraryColumnNavigation) -> AnyView

    @State private var error: VocabularyError?
    /// Not derived from the selection: popping the stack to its first screen reports `.sidebar`.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    /// `root` builds what the sidebar selects, and `page` what is pushed over it.
    public init(
        viewModel: LibraryViewModel,
        navigation: LibraryNavigation,
        root: @escaping (LibrarySelection, LibraryColumnNavigation) -> AnyView,
        page: @escaping (LibraryPage, LibraryColumnNavigation) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.root = root
        self.page = page
    }

    public var body: some View {
        let state = viewModel.state
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            LibrarySidebar(state: state, onAction: { action in
                viewModel.send(action)
                if case .selected(.some) = action { compactColumn = .detail }
            })
        } detail: {
            NavigationStack(path: Binding(get: { viewModel.state.path }, set: { viewModel.send(.pathChanged($0)) })) {
                Group {
                    if let selection = state.selection {
                        root(selection, columnNavigation).id(selection)
                    } else {
                        ContentUnavailableView("Choose a folder", systemImage: "folder")
                    }
                }
                .navigationDestination(for: LibraryPage.self) { page($0, columnNavigation) }
            }
        }
        .onAppear { viewModel.send(.appeared) }
        .onDisappear { viewModel.send(.disappeared) }
        .task {
            for await effect in viewModel.effects() {
                switch effect {
                case .requestMatching(let request): navigation.didRequestMatching(request)
                case .showError(let error): self.error = error
                }
            }
        }
        .errorAlert($error)
    }

    private var columnNavigation: LibraryColumnNavigation {
        LibraryColumnNavigation(
            openDeck: { viewModel.send(.opened(.deck($0))) },
            openFolder: { viewModel.send(.opened(.folder($0))) },
            expansion: { folderID in
                let layout = viewModel.state.layout
                return FolderExpansion(
                    expanded: layout.expanded(in: .folder(folderID)),
                    isSectionFolded: layout.foldedSections.contains(folderID),
                    setExpanded: { viewModel.send(.folderExpanded($0, $1, in: .folder(folderID))) },
                    toggleSection: { viewModel.send(.folderSectionToggled(folderID)) }
                )
            }
        )
    }
}
