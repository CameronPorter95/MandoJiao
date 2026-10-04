import CoreDesignSystem
import CoreUI
import SwiftUI
import VocabularyDomain

/// The tree of folders, searchable: while the search is open, every word in the library
/// shows in its place, filtered as typed.
struct LibrarySidebar: View {
    let state: LibraryState
    /// The search's results for what has been typed.
    let results: (String) -> AnyView
    let onAction: (LibraryAction) -> Void

    var body: some View {
        Group {
            if state.isSearching {
                results(state.searchText)
            } else {
                outline
            }
        }
        .searchField(
            initial: state.searchText,
            prompt: "Search words",
            onChange: { onAction(.searchChanged($0)) },
            onPresentedChange: { onAction(.searchPresentedChanged($0)) }
        )
        .navigationTitle("My Vocabulary")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(state.isEditing ? "Done" : "Edit") { onAction(.editTapped) }
                Button {
                    onAction(.newFolderTapped(parentID: nil))
                } label: {
                    Label("New folder", systemImage: "folder.badge.plus")
                }
                Menu {
                    Button { onAction(.newWordTapped) } label: {
                        Label("New word…", systemImage: "character.book.closed")
                    }
                    Button { onAction(.hskLevelsTapped) } label: {
                        Label("HSK levels…", systemImage: "graduationcap")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .namingAlert(
            state.namingTitle,
            isPresented: state.naming != nil,
            name: state.name,
            message: state.namingMessage,
            confirm: isNew ? "Create" : "Rename",
            onNameChanged: { onAction(.nameChanged($0)) },
            onConfirm: { onAction(.namingConfirmed) },
            onCancel: { onAction(.namingCancelled) }
        )
        .folderDeletionDialog(
            state.deletionWarning,
            onConfirm: { onAction(.deleteFolderConfirmed) },
            onCancel: { onAction(.deleteFolderCancelled) }
        )
    }

    private var outline: some View {
        FolderOutline(
            nodes: nodes(in: nil),
            selection: outlineSelection,
            expanded: state.layout.expanded(in: .tree),
            isEditing: state.isEditing,
            canMove: { state.vocabulary.canMoveFolder($0.item, into: $0.parent) },
            onMove: { onAction(.folderMoved(id: $0.item, parentID: $0.parent, index: $0.index)) },
            onSelect: { if case .node(let id) = $0 { onAction(.selected(.folder(id))) } },
            onExpand: { onAction(.folderExpanded($0, $1, in: .tree)) },
            actions: actions(for:),
            canPractise: state.canPractise,
            onPractise: { onAction(.practiseFolderTapped($0)) },
            onDelete: { onAction(.deleteFolderTapped($0)) }
        )
    }

    private var isNew: Bool {
        if case .new = state.naming { true } else { false }
    }

    private func nodes(in parentID: UUID?) -> [OutlineNode<UUID>] {
        state.vocabulary.folders(in: parentID).map {
            OutlineNode(id: $0.id, title: $0.displayName, children: nodes(in: $0.id))
        }
    }

    private var outlineSelection: OutlineSelection<UUID>? {
        switch state.selection {
        case .folder(let id): .node(id)
        case nil: nil
        }
    }

    private func actions(for id: UUID) -> [OutlineAction] {
        [
            OutlineAction("Practise", systemImage: "play.fill") { onAction(.practiseFolderTapped(id)) },
            OutlineAction("New folder inside", systemImage: "folder.badge.plus") { onAction(.newFolderTapped(parentID: id)) },
            OutlineAction("Rename", systemImage: "pencil") { onAction(.renameFolderTapped(id)) },
            OutlineAction("Delete", systemImage: "trash", isDestructive: true) { onAction(.deleteFolderTapped(id)) },
        ]
    }
}
