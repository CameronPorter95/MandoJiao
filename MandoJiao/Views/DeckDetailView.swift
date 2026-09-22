import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Bindable var deck: Deck
    let onStart: (LessonRequest) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabWord.english) private var allWords: [VocabWord]

    @State private var searchText = ""

    private var filteredWords: [VocabWord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allWords }
        return allWords.filter {
            $0.english.lowercased().contains(query)
                || $0.hanzi.contains(query)
                || $0.pinyin.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Deck name", text: $deck.name)

                Button {
                    onStart(LessonRequest(title: deck.name, pool: deck.words.pairs))
                    dismiss()
                } label: {
                    Text("Start lesson")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!deck.canStartLesson)
            } footer: {
                if !deck.canStartLesson {
                    Text("Pick at least \(LessonBuilder.pairsPerExercise) words to practise this deck.")
                }
            }

            Section {
                ForEach(filteredWords) { word in
                    Button {
                        toggle(word)
                    } label: {
                        HStack {
                            WordRow(word: word)
                            Spacer()
                            Image(systemName: isIncluded(word) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isIncluded(word) ? Theme.accent : Color.secondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Words")
                    Spacer()
                    Text("\(deck.usableWordCount) selected")
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search words")
        .navigationTitle(deck.name.isEmpty ? "Deck" : deck.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isIncluded(_ word: VocabWord) -> Bool {
        deck.words.contains { $0.uuid == word.uuid }
    }

    private func toggle(_ word: VocabWord) {
        if let index = deck.words.firstIndex(where: { $0.uuid == word.uuid }) {
            deck.words.remove(at: index)
        } else {
            deck.words.append(word)
        }
    }
}
