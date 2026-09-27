import SwiftUI
import VocabularyDomain

struct WordLibraryScreen: View {
    let state: WordLibraryState
    let onAction: (WordLibraryAction) -> Void

    var body: some View {
        let filteredWords = state.filteredWords
        List {
            ForEach(filteredWords) { word in
                Button {
                    onAction(.editTapped(word.id))
                } label: {
                    HStack {
                        WordRow(word: word)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                onAction(.deleteTapped(offsets.map { filteredWords[$0].id }))
            }
        }
        .overlay {
            if state.vocabulary.words.isEmpty {
                ContentUnavailableView(
                    "No words yet",
                    systemImage: "character.book.closed",
                    description: Text("Add English and Hanzi pairs to practise with.")
                )
            } else if filteredWords.isEmpty {
                ContentUnavailableView.search(text: state.searchText)
            }
        }
        .searchable(
            text: Binding(get: { state.searchText }, set: { onAction(.searchChanged($0)) }),
            prompt: "Search words"
        )
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onAction(.addTapped)
                } label: {
                    Label("Add word", systemImage: "plus")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WordLibraryScreen(
            state: WordLibraryState(vocabulary: SampleVocabulary.previewVocabulary),
            onAction: { _ in }
        )
    }
}
