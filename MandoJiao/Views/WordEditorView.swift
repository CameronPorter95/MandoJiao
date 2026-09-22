import SwiftData
import SwiftUI

struct WordEditorView: View {
    /// `nil` means a new word.
    let word: VocabWord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var english = ""
    @State private var hanzi = ""
    @State private var pinyin = ""

    private var canSave: Bool {
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("English") {
                    TextField("to drink", text: $english)
                        .textInputAutocapitalization(.never)
                }
                Section("Hanzi") {
                    TextField("喝", text: $hanzi)
                        .font(.system(size: 24))
                }
                Section {
                    TextField("hē", text: $pinyin)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Pinyin")
                } footer: {
                    Text("Optional. Shown once a pair is matched and in the lesson summary, never on an unsolved tile.")
                }

                if let word {
                    Section {
                        Button("Delete word", role: .destructive) {
                            context.delete(word)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(word == nil ? "New word" : "Edit word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let word else { return }
        english = word.english
        hanzi = word.hanzi
        pinyin = word.pinyin
    }

    private func save() {
        let trimmedEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHanzi = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPinyin = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEnglish.isEmpty, !trimmedHanzi.isEmpty else { return }

        if let word {
            word.english = trimmedEnglish
            word.hanzi = trimmedHanzi
            word.pinyin = trimmedPinyin
        } else {
            context.insert(
                VocabWord(english: trimmedEnglish, hanzi: trimmedHanzi, pinyin: trimmedPinyin)
            )
        }
        dismiss()
    }
}

#Preview {
    WordEditorView(word: nil)
        .modelContainer(PreviewData.container)
}
