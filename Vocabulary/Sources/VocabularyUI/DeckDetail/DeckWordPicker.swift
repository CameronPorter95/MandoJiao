import CoreDesignSystem
import CoreUI
import SwiftUI
import VocabularyDomain

/// Every word in the library, ticked when it is in the deck. A tap adds it or takes it out
/// at once, so Done only closes the sheet.
struct DeckWordPicker: View {
    let state: DeckDetailState
    let onAction: (DeckDetailAction) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.pickerWords) { word in
                        Button {
                            onAction(.wordToggled(word.id))
                        } label: {
                            HStack {
                                WordRow(word: word)
                                Spacer()
                                Image(systemName: state.isIncluded(word.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(state.isIncluded(word.id) ? Theme.accent : Color.secondary.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(state.wordCount) in \(state.title)")
                        .textCase(nil)
                }
            }
            .overlay {
                if state.vocabulary.words.isEmpty {
                    ContentUnavailableView(
                        "No words yet",
                        systemImage: "character.book.closed",
                        description: Text("Add words in All words, then pick them here.")
                    )
                } else if state.pickerWords.isEmpty {
                    ContentUnavailableView.search(text: state.pickerSearchText)
                }
            }
            .searchField(initial: state.pickerSearchText, prompt: "Search words") { onAction(.pickerSearchChanged($0)) }
            .navigationTitle("Add words")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onAction(.addWordsDismissed) }
                }
            }
        }
    }
}
