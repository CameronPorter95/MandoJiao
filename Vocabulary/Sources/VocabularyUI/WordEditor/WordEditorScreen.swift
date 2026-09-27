import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct WordEditorScreen: View {
    let state: WordEditorState
    let onAction: (WordEditorAction) -> Void

    @State private var newMeaning = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hanzi", text: binding(\.hanzi, WordEditorAction.hanziChanged), prompt: Text("喝"))
                        .font(.system(size: 24))
                } header: {
                    Text("Hanzi")
                } footer: {
                    Text("Meanings and pinyin are suggested from CC-CEDICT once the Hanzi is entered.")
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
                meaningsSection

                ForEach(state.entries, id: \.pinyin) { entry in
                    DictionarySensesSection(
                        entry: entry,
                        isOnlyReading: state.entries.count == 1,
                        isChosen: state.isChosen,
                        onToggle: { onAction(.senseToggled($0)) }
                    )
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

    private var meaningsSection: some View {
        Section {
            if state.meanings.isEmpty {
                Text(state.entries.isEmpty ? "Add one below." : "Tick one below, or add your own.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(state.meanings.enumerated()), id: \.element) { index, meaning in
                HStack(alignment: .firstTextBaseline) {
                    Text(meaning)
                        .foregroundStyle(state.meaningsAreSuggested ? Theme.accent : .primary)
                    Spacer()
                    if index == 0 {
                        Text("Headline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contextMenu {
                    if index > 0 {
                        Button { onAction(.meaningMadeHeadline(meaning)) } label: {
                            Label("Make headline", systemImage: "arrow.up.to.line")
                        }
                    }
                    Button(role: .destructive) { onAction(.meaningsRemoved([index])) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .onMove { onAction(.meaningsMoved(from: $0, to: $1)) }
            .onDelete { onAction(.meaningsRemoved($0)) }

            TextField("Add a meaning", text: $newMeaning)
                .neverAutocapitalize()
                .submitLabel(.done)
                .onSubmit {
                    onAction(.meaningAdded(newMeaning))
                    newMeaning = ""
                }
        } header: {
            Text("Meanings")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if state.meaningsAreSuggested {
                    Text("Suggested, and saved unless you change it.")
                }
                Text("The headline is shown on tiles and prompts, the rest once the answer is out. Drag to reorder, swipe to remove.")
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
            draft: WordDraft(hanzi: "行"),
            lookup: WordEditorState.Lookup(
                hanzi: "行",
                suggestion: WordSuggestion(hanzi: "行", pinyin: "xíng", english: "to walk"),
                entries: [
                    DictionaryEntry(simplified: "行", traditional: "行", pinyin: "xíng", isPreferred: true, senses: [
                        "to walk", "to go", "to travel", "a visit", "temporary", "makeshift",
                        "current", "in circulation", "to do", "to perform", "capable", "competent", "okay",
                    ]),
                    DictionaryEntry(simplified: "行", traditional: "行", pinyin: "háng", isPreferred: false, senses: [
                        "row, line", "commercial firm", "line of business", "profession",
                    ]),
                ]
            )
        ),
        onAction: { _ in }
    )
}

/// One reading's senses, ticked when they are among the word's meanings. A character can
/// have dozens, so the list starts short.
private struct DictionarySensesSection: View {
    let entry: DictionaryEntry
    let isOnlyReading: Bool
    let isChosen: (String) -> Bool
    let onToggle: (String) -> Void

    @State private var showsAll = false
    private static let shortLength = 6

    var body: some View {
        Section {
            ForEach(showsAll ? entry.senses : Array(entry.senses.prefix(Self.shortLength)), id: \.self) { sense in
                Button { onToggle(sense) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(sense)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if isChosen(sense) {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .accessibilityAddTraits(isChosen(sense) ? .isSelected : [])
            }
            if entry.senses.count > Self.shortLength {
                Button(showsAll ? "Show fewer" : "Show all \(entry.senses.count)") {
                    withAnimation { showsAll.toggle() }
                }
            }
        } header: {
            Text(isOnlyReading ? "From the dictionary" : "From the dictionary, \(entry.pinyin)")
        } footer: {
            if isOnlyReading || entry.isPreferred {
                Text("Tick a sense to add it as a meaning.")
            }
        }
    }
}
