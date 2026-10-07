import CoreDesignSystem
import CoreUI
import SwiftUI
import VocabularyDomain

struct FolderDetailScreen: View {
    let state: FolderDetailState
    let layout: FolderLayout
    let onAction: (FolderDetailAction) -> Void
    let onOpenDeck: (UUID) -> Void
    let onOpenFolder: (UUID) -> Void
    /// The search's results for what has been typed: every word in the decks beneath.
    let results: (String) -> AnyView

    /// While the search is open, the folder's words show in place of its folders and decks.
    var body: some View {
        Group {
            if state.isSearching {
                results(state.searchText)
            } else {
                contents
            }
        }
        .searchField(
            initial: state.searchText,
            prompt: "Search words",
            onChange: { onAction(.searchChanged($0)) },
            onPresentedChange: { onAction(.searchPresentedChanged($0)) }
        )
        .navigationTitle(state.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { onAction(.namingTapped(.newDeck)) } label: {
                    Label("New deck", systemImage: "plus")
                }
                Button { onAction(.namingTapped(.newFolder)) } label: {
                    Label("New folder", systemImage: "folder.badge.plus")
                }
                Menu {
                    Button { onAction(.namingTapped(.rename)) } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Divider()
                    DeckSortMenu(sort: layout.deckSort, onChange: layout.setDeckSort)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .namingAlert(
            namingTitle,
            isPresented: state.naming != nil,
            name: state.newName,
            message: namingMessage,
            confirm: state.naming == .rename ? "Rename" : "Create",
            onNameChanged: { onAction(.newNameChanged($0)) },
            onConfirm: { onAction(.namingConfirmed) },
            onCancel: { onAction(.namingCancelled) }
        )
        .folderDeletionDialog(
            state.deletionWarning,
            onConfirm: { onAction(.deleteFolderConfirmed) },
            onCancel: { onAction(.deleteFolderCancelled) }
        )
    }

    // Not List(selection:), which turns a tap on Start lesson into a row selection.
    private var contents: some View {
        List {
            Section {
                if !state.folderWords.isEmpty {
                    BandBreakdown(counts: state.folderWords.bandCounts(at: .now))
                        .padding(.vertical, 4)
                }
                PractiseRows(wordCount: state.wordCount, minimumMatchingWords: state.minimumMatchingWords) {
                    onAction(.startLessonTapped($0))
                }
            } header: {
                Text(state.summary)
                    .textCase(nil)
            } footer: {
                if state.canStart(.flashcards) {
                    Text("A lesson draws from all \(state.wordCount) words in this folder, including its folders.")
                } else {
                    Text("The decks in this folder have no words to practise yet.")
                }
            }

            if !state.subfolders.isEmpty {
                Section {
                    if !layout.foldedSections.contains(.folders) {
                        ForEach(state.subfolders) { subfolder in
                            SubfolderRow(
                                subfolder: subfolder,
                                layout: layout,
                                onOpen: onOpenFolder,
                                canPractise: { state.canPractise(folder: $0) },
                                onPractise: { onAction(.practiseFolderTapped($0)) },
                                onDelete: { onAction(.deleteFolderTapped($0)) }
                            )
                        }
                    }
                } header: {
                    FoldableHeader(title: "Folders", section: .folders, layout: layout)
                }
            }

            Section {
                if !layout.foldedSections.contains(.decks) {
                    if state.decks.isEmpty {
                        Text("No decks here yet. Add one with the + button.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(state.decks(sortedBy: layout.deckSort)) { deck in
                        deckRow(deck)
                    }
                }
            } header: {
                FoldableHeader(title: "Decks", section: .decks, layout: layout)
            } footer: {
                if !state.decks.isEmpty, !layout.foldedSections.contains(.decks) {
                    Text("Swipe right to practise a deck.")
                }
            }
        }
        .insetGroupedList()
    }

    private var namingTitle: String {
        switch state.naming {
        case .newFolder: "New folder"
        case .rename: "Rename folder"
        case .newDeck, nil: "New deck"
        }
    }

    private var namingMessage: String {
        switch state.naming {
        case .newFolder: "It goes inside \(state.title)."
        case .rename: ""
        case .newDeck, nil: "Give the deck a name, then pick its words."
        }
    }

    private func deckRow(_ deck: DeckSummary) -> some View {
        Button {
            onOpenDeck(deck.id)
        } label: {
            DeckRow(deck: deck, vocabulary: state.vocabulary, minimumMatchingWords: state.minimumMatchingWords)
        }
        .tint(.primary)
        .swipeActions(edge: .leading) {
            if state.canPractise(deck) {
                Button {
                    onAction(.practiseDeckTapped(deck.id))
                } label: {
                    Label("Practise", systemImage: "play.fill")
                }
                .tint(Theme.accent)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onAction(.deleteDeckTapped(deck.id))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Folds one of the folder's own sections, remembered in the library layout.
private struct FoldableHeader: View {
    let title: String
    let section: LibraryLayout.Section
    let layout: FolderLayout

    var body: some View {
        FoldingHeader(title: title, isFolded: layout.foldedSections.contains(section)) {
            layout.toggle(section)
        }
    }
}

/// Sort by, as a submenu: the field, then an order named for that field.
private struct DeckSortMenu: View {
    let sort: DeckSort
    let onChange: (DeckSort) -> Void

    var body: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { sort.field },
                set: { onChange(DeckSort(field: $0, ascending: $0.startsAscending)) }
            )) {
                ForEach(DeckSort.Field.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Order", selection: Binding(
                get: { sort.ascending },
                set: { onChange(DeckSort(field: sort.field, ascending: $0)) }
            )) {
                ForEach(sort.field.orders, id: \.ascending) { Text($0.title).tag($0.ascending) }
            }
        } label: {
            Label {
                Text("Sort by")
                Text(sort.field.title)
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }
}

private extension DeckSort.Field {
    var title: String {
        switch self {
        case .dateEdited: "Date Edited"
        case .dateCreated: "Date Created"
        case .title: "Title"
        case .size: "Size"
        }
    }

    /// Newest and largest first, but titles from A.
    var startsAscending: Bool { self == .title }

    /// Each order's name for this field, the first being the one it starts in.
    var orders: [(title: String, ascending: Bool)] {
        switch self {
        case .dateEdited, .dateCreated: [("Latest First", false), ("Oldest First", true)]
        case .title: [("Ascending", true), ("Descending", false)]
        case .size: [("Largest First", false), ("Smallest First", true)]
        }
    }
}

/// A folder beneath the one shown, folded or not as it was last left on this screen.
private struct SubfolderRow: View {
    let subfolder: FolderDetailState.Subfolder
    let layout: FolderLayout
    let onOpen: (UUID) -> Void
    let canPractise: (UUID) -> Bool
    let onPractise: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        if let children = subfolder.children {
            DisclosureGroup(isExpanded: Binding(
                get: { layout.expanded.contains(subfolder.id) },
                set: { layout.setExpanded(subfolder.id, $0) }
            )) {
                ForEach(children) {
                    SubfolderRow(
                        subfolder: $0,
                        layout: layout,
                        onOpen: onOpen,
                        canPractise: canPractise,
                        onPractise: onPractise,
                        onDelete: onDelete
                    )
                }
            } label: {
                row
            }
            .swipeActions(edge: .leading) { practiseButton }
            .swipeActions(edge: .trailing) { deleteButton }
        } else {
            row
                .swipeActions(edge: .leading) { practiseButton }
                .swipeActions(edge: .trailing) { deleteButton }
        }
    }

    @ViewBuilder
    private var practiseButton: some View {
        if canPractise(subfolder.id) {
            Button {
                onPractise(subfolder.id)
            } label: {
                Label("Practise", systemImage: "play.fill")
            }
            .tint(Theme.accent)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete(subfolder.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var row: some View {
        Button {
            onOpen(subfolder.id)
        } label: {
            LabeledContent {
                Text("\(subfolder.deckCount)")
            } label: {
                Label(subfolder.folder.displayName, systemImage: "folder")
            }
        }
        .tint(.primary)
    }
}
