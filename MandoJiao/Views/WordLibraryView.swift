import SwiftData
import SwiftUI

struct WordLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabWord.english) private var words: [VocabWord]

    @State private var searchText = ""
    @State private var editingWord: VocabWord?
    @State private var isAddingWord = false

    private var filteredWords: [VocabWord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return words }
        return words.filter {
            $0.english.lowercased().contains(query)
                || $0.hanzi.contains(query)
                || $0.pinyin.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filteredWords) { word in
                Button {
                    editingWord = word
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
            .onDelete(perform: delete)
        }
        .overlay {
            if words.isEmpty {
                ContentUnavailableView(
                    "No words yet",
                    systemImage: "character.book.closed",
                    description: Text("Add English and Hanzi pairs to practise with.")
                )
            } else if filteredWords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search words")
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingWord = true
                } label: {
                    Label("Add word", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingWord) {
            WordEditorView(word: nil)
        }
        .sheet(item: $editingWord) { word in
            WordEditorView(word: word)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredWords[index])
        }
    }
}

#Preview {
    NavigationStack {
        WordLibraryView()
    }
    .modelContainer(PreviewData.container)
}
