import CoreUI
import SwiftUI

/// The sidebar, then what it has open, then the open deck. On iPhone the columns become a
/// push stack, driven by the same selection.
public struct LibraryRoute: View {
    @State private var viewModel: LibraryViewModel
    private let navigation: LibraryNavigation
    private let content: (LibrarySelection, UUID?, LibraryColumnNavigation) -> AnyView
    private let detail: (UUID) -> AnyView

    @State private var error: VocabularyError?

    /// `content` is given what is selected, the open deck, and how to open something else.
    public init(
        viewModel: LibraryViewModel,
        navigation: LibraryNavigation,
        content: @escaping (LibrarySelection, UUID?, LibraryColumnNavigation) -> AnyView,
        detail: @escaping (UUID) -> AnyView
    ) {
        _viewModel = State(initialValue: viewModel)
        self.navigation = navigation
        self.content = content
        self.detail = detail
    }

    public var body: some View {
        let state = viewModel.state
        NavigationSplitView(preferredCompactColumn: compactColumn) {
            LibrarySidebar(state: state, onAction: { viewModel.send($0) })
        } content: {
            if let selection = state.selection {
                content(selection, state.openDeck, columnNavigation)
                    .id(selection)
            } else {
                ContentUnavailableView("Choose a folder", systemImage: "folder")
            }
        } detail: {
            if let deck = state.openDeck {
                detail(deck).id(deck)
            } else {
                ContentUnavailableView("Choose a deck", systemImage: "rectangle.stack")
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
            openDeck: { viewModel.send(.deckOpened($0)) },
            openFolder: { viewModel.send(.selected(.folder($0))) }
        )
    }

    private var compactColumn: Binding<NavigationSplitViewColumn> {
        Binding(
            get: {
                let state = viewModel.state
                if state.openDeck != nil { return .detail }
                return state.selection == nil ? .sidebar : .content
            },
            set: { column in
                switch column {
                case .sidebar: viewModel.send(.selected(nil))
                case .content: viewModel.send(.deckOpened(nil))
                default: break
                }
            }
        )
    }
}
