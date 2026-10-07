import CoreDesignSystem
import CoreUI
import LibraryDomain
import SwiftUI

struct DeckDetailScreen: View {
    let state: DeckDetailState
    let onAction: (DeckDetailAction) -> Void

    var body: some View {
        List {
            Section {
                TextField(
                    "Deck name",
                    text: Binding(get: { state.name ?? "" }, set: { onAction(.nameChanged($0)) })
                )
            }

            Section("Practise") {
                if !state.deckWords.isEmpty {
                    BandBreakdown(bandCounts: state.deckWords.bandCounts(at: .now))
                        .padding(.vertical, 4)
                }
                PractiseRows(wordCount: state.selectedCount, minimumMatchingWords: state.minimumMatchingWords) {
                    onAction(.startLessonTapped($0))
                }
            }

            Section {
                if state.wordCount == 0 {
                    Text("No words in this deck yet. Add some with the + button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(state.words) { word in
                    WordRow(word: word)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onAction(.removeTapped(word.id))
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Words")
                    Spacer()
                    Text(state.wordCount == 1 ? "1 word" : "\(state.wordCount) words")
                        .font(.caption)
                        .textCase(nil)
                }
            } footer: {
                if state.wordCount > 0 {
                    Text("Swipe left to take a word out of this deck. It stays in your vocabulary.")
                }
            }
        }
        .overlay {
            if state.wordCount > 0, state.words.isEmpty {
                ContentUnavailableView.search(text: state.searchText)
            }
        }
        .searchField(initial: state.searchText, prompt: "Search this deck") { onAction(.searchChanged($0)) }
        .navigationTitle(state.title)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    onAction(.addWordsTapped)
                } label: {
                    Label("Add words", systemImage: "plus")
                }
                Menu {
                    Button {
                        onAction(.moveTapped)
                    } label: {
                        Label("Move to…", systemImage: "folder")
                        if let reason = state.moveUnavailableReason { Text(reason) }
                    }
                    .disabled(state.moveUnavailableReason != nil)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { state.isChoosingDestination },
                set: { if !$0 { onAction(.moveCancelled) } }
            )
        ) {
            MoveDestinationPicker(
                title: "Move \(state.title)",
                destinations: state.destinations,
                onChoose: { onAction(.destinationChosen($0)) },
                onCancel: { onAction(.moveCancelled) }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { state.isAddingWords },
                set: { if !$0 { onAction(.addWordsDismissed) } }
            )
        ) {
            DeckWordPicker(state: state, onAction: onAction)
        }
    }
}
