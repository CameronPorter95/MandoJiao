import CoreDesignSystem
import SwiftUI
import VocabularyDomain

/// The tree of folders, with All words and the top-level decks pinned above it.
struct LibrarySidebar: View {
    let state: LibraryState
    let onAction: (LibraryAction) -> Void

    private static let pinned = [
        OutlinePinnedRow(id: "allWords", title: "All words", systemImage: "character.book.closed"),
        OutlinePinnedRow(id: "decks", title: "Decks", systemImage: "rectangle.stack"),
    ]

    var body: some View {
        FolderOutline(
            pinned: Self.pinned,
            nodes: nodes(in: nil),
            selection: outlineSelection,
            isEditing: state.isEditing,
            canMove: { state.vocabulary.canMoveFolder($0.item, into: $0.parent) },
            onMove: { onAction(.folderMoved(id: $0.item, parentID: $0.parent, index: $0.index)) },
            onSelect: { onAction(.selected(librarySelection($0))) },
            actions: actions(for:)
        )
        .navigationTitle("Library")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(state.isEditing ? "Done" : "Edit") { onAction(.editTapped) }
                Button {
                    onAction(.newFolderTapped(parentID: nil))
                } label: {
                    Label("New folder", systemImage: "folder.badge.plus")
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
        case .allWords: .pinned("allWords")
        case .topLevelDecks: .pinned("decks")
        case .folder(let id): .node(id)
        case nil: nil
        }
    }

    private func librarySelection(_ selection: OutlineSelection<UUID>) -> LibrarySelection {
        switch selection {
        case .pinned("allWords"): .allWords
        case .pinned: .topLevelDecks
        case .node(let id): .folder(id)
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
