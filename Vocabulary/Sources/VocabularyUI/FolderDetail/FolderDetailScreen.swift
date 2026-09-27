import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct FolderDetailScreen: View {
    let state: FolderDetailState
    /// The deck open in the next column, highlighted at regular width.
    let openDeck: UUID?
    let onAction: (FolderDetailAction) -> Void
    let onOpenDeck: (UUID) -> Void

    var body: some View {
        List(selection: Binding(get: { openDeck }, set: { $0.map(onOpenDeck) })) {
            if state.practisesAsWhole {
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
                } footer: {
                    if state.canStartLesson {
                        Text("A lesson draws from all \(state.wordCount) words in this folder, including its folders.")
                    } else {
                        Text("The decks in this folder need at least \(state.minimumMatchingWords) words between them.")
                    }
                }
            }

            Section {
                if state.decks.isEmpty {
                    Text("No decks here yet. Add one with the + button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(state.decks) { deck in
                    DeckRow(deck: deck, vocabulary: state.vocabulary, minimumMatchingWords: state.minimumMatchingWords)
                        .tag(deck.id)
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
                    Text("Swipe right to practise a deck. Edit to reorder.")
                }
            }
        }
        .insetGroupedList()
        .navigationTitle(state.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditModeButton()
                Button {
                    onAction(.newDeckTapped)
                } label: {
                    Label("New deck", systemImage: "rectangle.stack.badge.plus")
                }
            }
        }
        .namingAlert(
            "New deck",
            isPresented: state.isNamingDeck,
            name: state.newDeckName,
            message: "Give the deck a name, then pick its words.",
            confirm: "Create",
            onNameChanged: { onAction(.newDeckNameChanged($0)) },
            onConfirm: { onAction(.createDeckConfirmed) },
            onCancel: { onAction(.createDeckCancelled) }
        )
    }
}
