import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct WordEditorScreen: View {
    let state: WordEditorState
    let onAction: (WordEditorAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hanzi", text: binding(\.hanzi, WordEditorAction.hanziChanged), prompt: Text("喝"))
                        .font(.system(size: 24))
                } header: {
                    Text("Hanzi")
                } footer: {
                    Text("Pinyin and English are suggested from CC-CEDICT once the Hanzi is entered.")
                }
                Section {
                    TextField(
                        "Pinyin",
                        text: binding(\.pinyin, WordEditorAction.pinyinChanged),
                        prompt: prompt(state.pinyinSuggestion, otherwise: "hē")
                    )
                    .neverAutocapitalize()
                } header: {
                    Text("Pinyin")
                } footer: {
                    if state.pinyinSuggestion != nil {
                        Text("Suggested, and saved unless you type over it. Shown once a pair is matched and in the lesson summary, never on an unsolved tile.")
                    } else {
                        Text("Optional. Shown once a pair is matched and in the lesson summary, never on an unsolved tile.")
                    }
                }
                Section {
                    TextField(
                        "English",
                        text: binding(\.english, WordEditorAction.englishChanged),
                        prompt: prompt(state.englishSuggestion, otherwise: "to drink")
                    )
                    .neverAutocapitalize()
                } header: {
                    Text("English")
                } footer: {
                    if state.englishSuggestion != nil {
                        Text("Suggested, and saved unless you type over it.")
                    }
                }

                if state.canDelete {
                    Section {
                        Button("Delete word", role: .destructive) { onAction(.deleteTapped) }
                    }
                }
            }
            .navigationTitle(state.title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onAction(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onAction(.saveTapped) }.disabled(!state.canSave)
                }
            }
        }
    }

    /// A suggestion is tinted, because a grey placeholder reads as empty and this one is saved.
    private func prompt(_ suggestion: String?, otherwise example: String) -> Text {
        guard let suggestion else { return Text(example) }
        return Text(suggestion).foregroundStyle(Theme.accent)
    }

    private func binding(
        _ field: KeyPath<WordDraft, String>,
        _ action: @escaping (String) -> WordEditorAction
    ) -> Binding<String> {
        Binding(get: { state.draft[keyPath: field] }, set: { onAction(action($0)) })
    }
}

#Preview("New") {
    WordEditorScreen(state: WordEditorState(wordID: nil, draft: WordDraft()), onAction: { _ in })
}

#Preview("Suggested") {
    WordEditorScreen(
        state: WordEditorState(
            wordID: nil,
            draft: WordDraft(hanzi: "银行"),
            suggestion: WordSuggestion(hanzi: "银行", pinyin: "yínháng", english: "bank")
        ),
        onAction: { _ in }
    )
}
