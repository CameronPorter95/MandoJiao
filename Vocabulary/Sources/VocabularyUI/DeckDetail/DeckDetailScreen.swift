import CoreDesignSystem
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

                Button {
                    onAction(.startLessonTapped)
                } label: {
                    Text("Start lesson")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!state.canStartLesson)
            } footer: {
                if !state.canStartLesson {
                    Text("Pick at least \(state.minimumMatchingWords) words to practise this deck.")
                }
            }

            Section {
                ForEach(state.filteredWords) { word in
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
                HStack {
                    Text("Words")
                    Spacer()
                    Text("\(state.selectedCount) selected")
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
        .searchable(
            text: Binding(get: { state.searchText }, set: { onAction(.searchChanged($0)) }),
            prompt: "Search words"
        )
        .navigationTitle(state.title)
        .inlineNavigationTitle()
    }
}
