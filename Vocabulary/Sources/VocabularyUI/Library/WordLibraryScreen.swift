import CoreDesignSystem
import CoreUI
import SwiftUI
import VocabularyDomain

struct WordLibraryScreen: View {
    let state: WordLibraryState
    let layout: WordListLayout
    let onAction: (WordLibraryAction) -> Void

    var body: some View {
        let filteredWords = state.words
        List {
            Section {
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
                        Button {
                            onAction(.learntToggled(word.id))
                        } label: {
                            Label(word.isLearnt ? "Unmark learnt" : "Mark as learnt", systemImage: "checkmark.seal")
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
            } header: {
                if state.hasWords {
                    HStack {
                        Text(state.count)
                        Spacer()
                        WordSortMenu(sort: layout.sort, onChange: layout.setSort)
                    }
                    .textCase(nil)
                }
            }
        }
        .insetGroupedList()
        .overlay {
            if !state.hasWords, state.folderID != nil {
                ContentUnavailableView(
                    "No words here yet",
                    systemImage: "character.book.closed",
                    description: Text("Words in this folder's decks, and in the decks of its folders, show here.")
                )
            } else if !state.hasWords {
                ContentUnavailableView(
                    "No words yet",
                    systemImage: "character.book.closed",
                    description: Text("Add English and Hanzi pairs to practise with.")
                )
            } else if filteredWords.isEmpty {
                ContentUnavailableView.search(text: state.searchText)
            }
        }
    }
}

/// The field, then an order named for that field, as a folder's screen sorts its decks.
/// Above the results rather than in the toolbar, which belongs to the screen searched.
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
            Label(sort.field.title, systemImage: "arrow.up.arrow.down")
                .font(.subheadline)
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
    let state = {
        var state = WordLibraryState(vocabulary: SampleVocabulary.previewVocabulary)
        state.relist()
        return state
    }()
    NavigationStack {
        WordLibraryScreen(
            state: state,
            layout: WordListLayout(sort: .default, setSort: { _ in }),
            onAction: { _ in }
        )
    }
}
