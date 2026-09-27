import CoreDesignSystem
import SwiftUI
import VocabularyDomain

/// Folders first, then decks, each with practise and delete swipes. Home and the folder
/// screen both list their contents this way.
struct FolderContents: View {
    let folders: [FolderSummary]
    let decks: [DeckSummary]
    let vocabulary: Vocabulary
    let minimumMatchingWords: Int
    let onPractiseFolder: (UUID) -> Void
    let onPractiseDeck: (UUID) -> Void
    let onDeleteFolder: (UUID) -> Void
    let onDeleteDeck: (UUID) -> Void

    var body: some View {
        ForEach(folders) { folder in
            NavigationLink(value: HomeDestination.folder(folder.id)) {
                FolderRow(folder: folder, vocabulary: vocabulary, minimumMatchingWords: minimumMatchingWords)
            }
            .swipeActions(edge: .leading) { practise { onPractiseFolder(folder.id) } }
            .swipeActions(edge: .trailing) { delete { onDeleteFolder(folder.id) } }
        }
        ForEach(decks) { deck in
            NavigationLink(value: HomeDestination.deck(deck.id)) {
                DeckRow(deck: deck, vocabulary: vocabulary, minimumMatchingWords: minimumMatchingWords)
            }
            .swipeActions(edge: .leading) { practise { onPractiseDeck(deck.id) } }
            .swipeActions(edge: .trailing) { delete { onDeleteDeck(deck.id) } }
        }
    }

    private func practise(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Practise", systemImage: "play.fill")
        }
        .tint(Theme.accent)
    }

    private func delete(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("Delete", systemImage: "trash")
        }
    }
}
