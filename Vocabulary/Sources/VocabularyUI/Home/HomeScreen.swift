import CoreDesignSystem
import SwiftUI
import VocabularyDomain

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
                if state.isEmptyOfDecks {
                    Text("No decks yet. Create one to practise a smaller set of words, or a folder to group decks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FolderContents(
                        folders: state.folders,
                        decks: state.decks,
                        vocabulary: state.vocabulary,
                        minimumMatchingWords: state.minimumMatchingWords,
                        onPractiseFolder: { onAction(.practiseFolderTapped($0)) },
                        onPractiseDeck: { onAction(.practiseDeckTapped($0)) },
                        onDeleteFolder: { onAction(.deleteFolderTapped($0)) },
                        onDeleteDeck: { onAction(.deleteDeckTapped($0)) }
                    )
                }
            } header: {
                Text("Decks and folders")
            } footer: {
                Text("Swipe right to practise. A deck holds words, and a folder holds decks and other folders.")
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
            }
            NewItemMenu { onAction(.newItemTapped($0)) }
        }
        .newItemAlert(
            state.naming,
            name: state.newItemName,
            onNameChanged: { onAction(.newItemNameChanged($0)) },
            onCreate: { onAction(.createConfirmed) },
            onCancel: { onAction(.createCancelled) }
        )
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
        .folderDeletionDialog(
            state.deletionWarning,
            onConfirm: { onAction(.deleteFolderConfirmed) },
            onCancel: { onAction(.deleteFolderCancelled) }
        )
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
}

#Preview {
    NavigationStack {
        HomeScreen(
            state: HomeState(vocabulary: SampleVocabulary.previewVocabulary, minimumMatchingWords: 5, quickPracticeRounds: 10),
            onAction: { _ in }
        )
    }
}
