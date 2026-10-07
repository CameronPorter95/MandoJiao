import CoreDesignSystem
import DictionaryDomain
import SwiftUI
import VocabularyDomain

struct WordEditorScreen: View {
    let state: WordEditorState
    let onAction: (WordEditorAction) -> Void

    @State private var newMeaning = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case meaning(Int)
        case newMeaning
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hanzi", text: binding(\.hanzi, WordEditorAction.hanziChanged), prompt: Text("喝"))
                        .font(.system(size: 24))
                } header: {
                    Text("Hanzi")
                } footer: {
                    Text("Pinyin and a meaning are suggested from CC-CEDICT once the Hanzi is entered.")
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

                if !state.deckSections.isEmpty {
                    deckSection
                }

                if state.dictionaryHeadword != nil {
                    dictionarySection
                }

                if state.canDelete {
                    Section {
                        Toggle("Learnt", isOn: Binding(get: { state.isLearnt }, set: { onAction(.learntToggled($0)) }))
                    } footer: {
                        Text("A learnt word counts as known at once, then fades like any other if it isn't practised. Settings can leave learnt words out of lessons.")
                    }

                    Section {
                        Button("Delete word", role: .destructive) { onAction(.deleteTapped) }
                    }
                }
            }
            .opacity(state.isLoading ? 0 : 1)
            .overlay {
                if state.isLoading { ProgressView() }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(state.title)
            .inlineNavigationTitle()
            .sheet(isPresented: Binding(
                get: { state.isChoosingSenses },
                set: { if !$0 { onAction(.sensesDismissed) } }
            )) {
                SensePicker(state: state, onAction: onAction)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onAction(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // A meaning typed but not yet added is kept, not lost.
                    Button("Save") {
                        addMeaning()
                        onAction(.saveTapped)
                    }
                    .disabled(!state.canSave)
                }
            }
        }
    }

    /// Each meaning is its own field, the first being the headline, with its reorder handle
    /// showing from the start. A new word starts with just the headline's field, and a
    /// field to add another appears once there is one.
    private var meaningsSection: some View {
        Section {
            ForEach(Array(state.meaningRows.enumerated()), id: \.offset) { index, meaning in
                HStack(alignment: .firstTextBaseline) {
                    TextField(
                        index == 0 ? "Headline meaning" : "Meaning",
                        text: Binding(get: { meaning }, set: { editMeaning(at: index, $0) }),
                        prompt: Text(index == 0 ? "Headline meaning, like to drink" : "Meaning"),
                        axis: .vertical
                    )
                    .neverAutocapitalize()
                    .foregroundStyle(state.meaningsAreSuggested ? Theme.accent : .primary)
                    .focused($focus, equals: .meaning(index))
                    if index == 0, state.canAddMeaning {
                        Text("Headline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // Drawn rather than edit mode's, whose delete buttons the owner did not
                    // want. Holding it starts the list's own drag; holding the text selects it.
                    if state.meanings.count > 1 {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                // A text field does not count as the row's text, so the separator would start
                // at the Headline label.
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                .deleteDisabled(state.meanings.isEmpty)
                .moveDisabled(state.meanings.count < 2)
            }
            .onMove { onAction(.meaningsMoved(from: $0, to: $1)) }
            .onDelete { onAction(.meaningsRemoved($0)) }

            if state.canAddMeaning {
                TextField("Add a meaning", text: $newMeaning)
                    .neverAutocapitalize()
                    .submitLabel(.done)
                    .focused($focus, equals: .newMeaning)
                    .onSubmit {
                        // Return on an empty field puts the keyboard away, else it stays for the next.
                        let isBlank = newMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        addMeaning()
                        focus = isBlank ? nil : .newMeaning
                    }
            }
        } header: {
            Text("Meanings")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if state.meaningsAreSuggested {
                    Text("Suggested from the dictionary, and saved unless you change it.")
                }
                Text("The headline is shown on tiles and prompts, the rest once the answer is out."
                    + (state.meanings.count > 1 ? " Hold and drag to reorder, swipe to remove." : ""))
            }
        }
    }

    /// Pushed rather than a menu, since the HSK levels alone bring dozens of decks. Not a
    /// `Picker`, whose collapsed row would show only the deck's own name, and Part 1 is in
    /// every HSK level.
    private var deckSection: some View {
        Section {
            NavigationLink {
                DeckPicker(state: state, onAction: onAction)
            } label: {
                LabeledContent("Deck", value: state.chosenDeckTitle)
            }
        } header: {
            Text("Add to")
        } footer: {
            Text("Optional. The word joins the deck, and so every folder above it.")
        }
    }

    /// Return in a meaning's field moves on to adding another rather than breaking the line.
    private func editMeaning(at index: Int, _ text: String) {
        guard text.contains("\n") else {
            onAction(.meaningEdited(at: index, text: text))
            return
        }
        onAction(.meaningEdited(at: index, text: text.replacingOccurrences(of: "\n", with: "")))
        focus = .newMeaning
    }

    private func addMeaning() {
        guard !newMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onAction(.meaningAdded(newMeaning))
        newMeaning = ""
    }

    /// Apart from the word's own fields, and only ever a way into the dictionary: its senses
    /// are never listed here, so what is the word's and what is the dictionary's stay apart.
    private var dictionarySection: some View {
        Section {
            if !state.tickableEntries.isEmpty {
                Button { onAction(.sensesTapped) } label: {
                    Label("Choose meanings from the dictionary", systemImage: "checklist")
                }
            }
            Button { onAction(.dictionaryTapped) } label: {
                Label("View in dictionary", systemImage: "character.book.closed")
            }
        } header: {
            Text("CC-CEDICT")
        } footer: {
            if !state.tickableEntries.isEmpty {
                Text("A meaning chosen there is copied into this word, where it is yours to edit.")
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

/// The dictionary's senses for the Hanzi, as a sheet of its own. Ticking one copies it into
/// the word's meanings, and unticking takes the copy out.
private struct SensePicker: View {
    let state: WordEditorState
    let onAction: (WordEditorAction) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(state.tickableEntries, id: \.pinyin) { entry in
                    DictionarySensesSection(
                        entry: entry,
                        isChosen: state.isChosen,
                        onToggle: { onAction(.senseToggled($0)) }
                    )
                }
            }
            .navigationTitle(state.draft.trimmed.hanzi)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onAction(.sensesDismissed) }
                }
            }
        }
    }
}

/// One reading's senses, ticked when they are among the word's meanings. A character can
/// have dozens, so the list starts short.
private struct DictionarySensesSection: View {
    let entry: DictionaryEntry
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
            Text(entry.pinyin)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
                .textCase(nil)
        }
    }
}

/// The decks a new word can join, a section per folder, so decks named alike in different
/// folders read apart. Each folds, as a folder's own sections do. Choosing one goes back to
/// the word.
private struct DeckPicker: View {
    let state: WordEditorState
    let onAction: (WordEditorAction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                row("None", isChosen: state.chosenDeckID == nil) { onAction(.deckChosen(nil)) }
            }
            ForEach(state.deckSections) { section in
                let isFolded = state.foldedDeckSections.contains(section.id)
                Section {
                    if !isFolded {
                        ForEach(section.decks) { deck in
                            row(deck.displayName, isChosen: state.chosenDeckID == deck.id) { onAction(.deckChosen(deck.id)) }
                        }
                    }
                } header: {
                    FoldingHeader(title: section.title, systemImage: "folder", isFolded: isFolded) {
                        onAction(.deckSectionToggled(section.id))
                    }
                }
            }
        }
        // The header's withAnimation does not reach a pushed screen, whose state arrives
        // from the editor in a later update, so the fold would snap without this.
        .animation(.default, value: state.foldedDeckSections)
        .navigationTitle("Add to")
        .inlineNavigationTitle()
    }

    private func row(_ title: String, isChosen: Bool, choose: @escaping () -> Void) -> some View {
        Button {
            choose()
            dismiss()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                if isChosen {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
