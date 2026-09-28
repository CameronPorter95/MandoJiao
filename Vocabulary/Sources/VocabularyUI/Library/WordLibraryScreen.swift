import CoreDesignSystem
import CoreUI
import SwiftUI
import VocabularyDomain

struct WordLibraryScreen: View {
    let state: WordLibraryState
    let layout: WordListLayout
    let onAction: (WordLibraryAction) -> Void

    var body: some View {
        let filteredWords = state.words(sortedBy: layout.sort)
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
                    .contentShape(Rectangle())
                }
                .tint(.primary)
                .swipeActions(edge: .leading) {
                    if !word.hanzi.isEmpty {
                        Button {
                            onAction(.dictionaryTapped(word.id))
                        } label: {
                            Label("Dictionary", systemImage: "character.book.closed")
                        }
                        .tint(Theme.accent)
                    }
                }
                .contextMenu {
                    Button {
                        onAction(.editTapped(word.id))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if !word.hanzi.isEmpty {
                        Button {
                            onAction(.dictionaryTapped(word.id))
                        } label: {
                            Label("View in dictionary", systemImage: "character.book.closed")
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onAction(.deleteTapped([word.id]))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
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
        .searchField(initial: state.searchText, prompt: "Search words") { onAction(.searchChanged($0)) }
        .navigationTitle("All words")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    onAction(.addTapped)
                } label: {
                    Label("Add word", systemImage: "plus")
                }
                Menu {
                    WordSortMenu(sort: layout.sort, onChange: layout.setSort)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }
}

/// Sort by, as a submenu: the field, then an order named for that field, as a folder's
/// screen sorts its decks.
private struct WordSortMenu: View {
    let sort: WordSort
    let onChange: (WordSort) -> Void

    var body: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { sort.field },
                set: { onChange(WordSort(field: $0, ascending: $0.startsAscending)) }
            )) {
                ForEach(WordSort.Field.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Order", selection: Binding(
                get: { sort.ascending },
                set: { onChange(WordSort(field: sort.field, ascending: $0)) }
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

private extension WordSort.Field {
    var title: String {
        switch self {
        case .english: "English"
        case .pinyin: "Pinyin"
        case .dateAdded: "Date Added"
        case .mistakes: "Mistakes"
        }
    }

    /// A to Z, but newest and most mistaken first.
    var startsAscending: Bool { self == .english || self == .pinyin }

    /// Each order's name for this field, the first being the one it starts in.
    var orders: [(title: String, ascending: Bool)] {
        switch self {
        case .english, .pinyin: [("Ascending", true), ("Descending", false)]
        case .dateAdded: [("Latest First", false), ("Oldest First", true)]
        case .mistakes: [("Most First", false), ("Fewest First", true)]
        }
    }
}

#Preview {
    NavigationStack {
        WordLibraryScreen(
            state: WordLibraryState(vocabulary: SampleVocabulary.previewVocabulary),
            layout: WordListLayout(sort: .default, setSort: { _ in }),
            onAction: { _ in }
        )
    }
}
