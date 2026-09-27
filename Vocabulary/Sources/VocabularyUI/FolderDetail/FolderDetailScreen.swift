import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct FolderDetailScreen: View {
    let state: FolderDetailState
    let expansion: FolderExpansion
    let onAction: (FolderDetailAction) -> Void
    let onOpenDeck: (UUID) -> Void
    let onOpenFolder: (UUID) -> Void

    // Not List(selection:), which turns a tap on Start lesson into a row selection.
    var body: some View {
        List {
            Section {
                Button {
                    onAction(.startLessonTapped)
                } label: {
                    Text("Start lesson")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!state.canStartLesson)
            } header: {
                Text(state.summary)
                    .textCase(nil)
            } footer: {
                if state.canStartLesson {
                    Text("A lesson draws from all \(state.wordCount) words in this folder, including its folders.")
                } else {
                    Text("The decks in this folder need at least \(state.minimumMatchingWords) words between them.")
                }
            }

            if !state.subfolders.isEmpty {
                let isSectionExpanded = !expansion.isSectionFolded
                Section {
                    if isSectionExpanded {
                        ForEach(state.subfolders) { subfolder in
                            SubfolderRow(subfolder: subfolder, expansion: expansion, onOpen: onOpenFolder)
                        }
                    }
                } header: {
                    Button {
                        withAnimation { expansion.toggleSection() }
                    } label: {
                        HStack {
                            Text("Folders")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(isSectionExpanded ? 0 : -90))
                                .accessibilityLabel(isSectionExpanded ? "Collapse" : "Expand")
                        }
                    }
                    .tint(.secondary)
                }
            }

            Section {
                if state.decks.isEmpty {
                    Text("No decks here yet. Add one with the + button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(state.decks) { deck in
                    Button {
                        onOpenDeck(deck.id)
                    } label: {
                        DeckRow(deck: deck, vocabulary: state.vocabulary, minimumMatchingWords: state.minimumMatchingWords)
                    }
                    .tint(.primary)
                    .swipeActions(edge: .leading) {
                        Button {
                            onAction(.practiseDeckTapped(deck.id))
                        } label: {
                            Label("Practise", systemImage: "play.fill")
                        }
                        .tint(Theme.accent)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onAction(.deleteDeckTapped(deck.id))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { onAction(.decksMoved(from: $0, to: $1)) }
            } header: {
                Text("Decks")
            } footer: {
                if !state.decks.isEmpty {
                    Text("Swipe right to practise a deck. Edit to reorder decks; rearrange folders in the library.")
                }
            }
        }
        .insetGroupedList()
        .navigationTitle(state.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditModeButton()
                Menu {
                    Button { onAction(.newItemTapped(.deck)) } label: {
                        Label("New deck", systemImage: "rectangle.stack.badge.plus")
                    }
                    Button { onAction(.newItemTapped(.folder)) } label: {
                        Label("New folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
        }
        .namingAlert(
            state.naming == .folder ? "New folder" : "New deck",
            isPresented: state.naming != nil,
            name: state.newName,
            message: state.naming == .folder
                ? "It goes inside \(state.title)."
                : "Give the deck a name, then pick its words.",
            confirm: "Create",
            onNameChanged: { onAction(.newNameChanged($0)) },
            onConfirm: { onAction(.createConfirmed) },
            onCancel: { onAction(.createCancelled) }
        )
    }
}

/// A folder beneath the one shown, folded or not as it was last left on this screen.
private struct SubfolderRow: View {
    let subfolder: FolderDetailState.Subfolder
    let expansion: FolderExpansion
    let onOpen: (UUID) -> Void

    var body: some View {
        if let children = subfolder.children {
            DisclosureGroup(isExpanded: Binding(
                get: { expansion.expanded.contains(subfolder.id) },
                set: { expansion.setExpanded(subfolder.id, $0) }
            )) {
                ForEach(children) { SubfolderRow(subfolder: $0, expansion: expansion, onOpen: onOpen) }
            } label: {
                row
            }
        } else {
            row
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
