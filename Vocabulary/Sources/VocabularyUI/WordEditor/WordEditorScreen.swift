import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct WordEditorScreen: View {
    let state: WordEditorState
    let onAction: (WordEditorAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("English") {
                    TextField("to drink", text: binding(\.english, WordEditorAction.englishChanged))
                        .neverAutocapitalize()
                }
                Section("Hanzi") {
                    TextField("喝", text: binding(\.hanzi, WordEditorAction.hanziChanged))
                        .font(.system(size: 24))
                }
                Section {
                    TextField("hē", text: binding(\.pinyin, WordEditorAction.pinyinChanged))
                        .neverAutocapitalize()
                } header: {
                    Text("Pinyin")
                } footer: {
                    Text("Optional. Shown once a pair is matched and in the lesson summary, never on an unsolved tile.")
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

    private func binding(
        _ field: KeyPath<WordDraft, String>,
        _ action: @escaping (String) -> WordEditorAction
    ) -> Binding<String> {
        Binding(get: { state.draft[keyPath: field] }, set: { onAction(action($0)) })
    }
}

#Preview {
    WordEditorScreen(state: WordEditorState(wordID: nil, draft: WordDraft()), onAction: { _ in })
}
