import SwiftUI

struct HomeScreen: View {
    let state: HomeState
    let onAction: (HomeAction) -> Void

    var body: some View {
        List {
            Section {
                quickPracticeCard
            }

            if !state.mistakeWords.isEmpty {
                Section {
                    mistakesCard
                }
            }

            Section {
                if state.vocabulary.decks.isEmpty {
                    Text("No decks yet. Create one to practise a smaller set of words.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.vocabulary.decks) { deck in
                        NavigationLink(value: HomeDestination.deck(deck.id)) {
                            deckRow(deck)
                        }
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
                }
            } header: {
                Text("Decks")
            } footer: {
                Text("Swipe a deck right to practise it, or open it to choose its words.")
            }
        }
        .navigationTitle("MandoJiao")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink(value: HomeDestination.settings) {
                    Label("Settings", systemImage: "gearshape")
                }

                NavigationLink(value: HomeDestination.library) {
                    Label("Library", systemImage: "character.book.closed")
                }

                Button {
                    onAction(.newDeckTapped)
                } label: {
                    Label("New deck", systemImage: "plus")
                }
            }
        }
        .alert(
            "New deck",
            isPresented: Binding(
                get: { state.isNamingDeck },
                set: { if !$0 { onAction(.createDeckCancelled) } }
            )
        ) {
            TextField(
                "Deck name",
                text: Binding(get: { state.newDeckName }, set: { onAction(.newDeckNameChanged($0)) })
            )
            Button("Create") { onAction(.createDeckConfirmed) }
            Button("Cancel", role: .cancel) { onAction(.createDeckCancelled) }
        } message: {
            Text("Give the deck a name, then pick its words.")
        }
        .confirmationDialog(
            "Clear the mistakes list?",
            isPresented: Binding(
                get: { state.isConfirmingClear },
                set: { if !$0 { onAction(.clearMistakesCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { onAction(.clearMistakesConfirmed) }
            Button("Cancel", role: .cancel) { onAction(.clearMistakesCancelled) }
        } message: {
            Text("\(state.mistakeWords.count) words will be marked as learned.")
        }
    }

    // MARK: - Pieces

    private var quickPracticeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick practice")
                    .font(.title3.bold())
                Text("\(state.quickPracticeRounds) rounds of \(state.minimumMatchingWords) pairs, drawn at random from all \(state.usableWordCount) words.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onAction(.quickPracticeTapped)
            } label: {
                Text("Start lesson")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(!state.canStartQuickPractice)

            if !state.canStartQuickPractice {
                Text("Add at least \(state.minimumMatchingWords) words to start a lesson.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var mistakesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mistakes")
                    .font(.title3.bold())
                Text(state.mistakesSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    onAction(.practiseMistakesTapped)
                } label: {
                    Label("Practise mistakes", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.miss)

                Button("Clear") { onAction(.clearMistakesTapped) }
                    .font(.subheadline)
                    .tint(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func deckRow(_ deck: DeckSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(deck.displayName)
                .font(.body.weight(.medium))
            Text(state.subtitle(for: deck))
                .font(.caption)
                .foregroundStyle(state.canStartLesson(with: deck) ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.miss))
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreen(
            state: HomeState(vocabulary: SampleVocabulary.previewVocabulary, minimumMatchingWords: 5, quickPracticeRounds: 10),
            onAction: { _ in }
        )
    }
}
