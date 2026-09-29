import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct DictionaryPageScreen: View {
    let state: DictionaryPageState
    let onAction: (DictionaryPageAction) -> Void

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text(state.headword.hanzi)
                        .font(.system(size: 56, weight: .medium))
                    if let traditional = state.traditional {
                        Text("Traditional \(traditional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            switch state.content {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)

            case .failed:
                Section {
                    Text("The dictionary could not be read.")
                    Button("Try again") { onAction(.retryTapped) }
                }

            case .loaded(let readings, let characters):
                if readings.isEmpty {
                    Section {
                        Text(characters.isEmpty ? "Not in CC-CEDICT." : "Not in CC-CEDICT as a whole, but its characters are.")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(readings) { reading in
                    ReadingSection(reading: reading, vocabulary: state.vocabulary(for: reading), onAction: onAction)
                }
                if !characters.isEmpty {
                    Section("Characters") {
                        ForEach(characters) { character in
                            NavigationLink(value: DictionaryHeadword(hanzi: character.hanzi, pinyin: character.pinyin)) {
                                CharacterRow(character: character)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(state.headword.hanzi)
        .inlineNavigationTitle()
        .onAppear { onAction(.appeared) }
        .onDisappear { onAction(.disappeared) }
    }
}

private struct ReadingSection: View {
    let reading: DictionaryPageState.Reading
    let vocabulary: ReadingInVocabulary?
    let onAction: (DictionaryPageAction) -> Void

    var body: some View {
        Section {
            if reading.entry.senses.isEmpty {
                Text("No meanings given.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(reading.entry.senses.enumerated()), id: \.offset) { index, sense in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    Text(sense)
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(reading.entry.pinyin)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                if let vocabulary {
                    Button {
                        onAction(.vocabularyTapped(reading.id))
                    } label: {
                        Label(
                            vocabulary.isSaved ? "In vocabulary" : "Add",
                            systemImage: vocabulary.isSaved ? "checkmark.circle.fill" : "plus.circle"
                        )
                        .font(.subheadline.weight(.medium))
                    }
                    .accessibilityHint(vocabulary.isSaved ? "Opens the saved word" : "Adds this reading to your vocabulary")
                }
            }
            .textCase(nil)
        }
    }
}

private struct CharacterRow: View {
    let character: DictionaryPageState.Character

    var body: some View {
        HStack(spacing: 12) {
            Text(character.hanzi)
                .font(.system(size: 26, weight: .medium))
            VStack(alignment: .leading, spacing: 1) {
                Text(character.pinyin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !character.gloss.isEmpty {
                    Text(character.gloss)
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DictionaryPageScreen(
            state: DictionaryPageState(
                headword: DictionaryHeadword(hanzi: "银行", pinyin: "yínháng"),
                content: .loaded(
                    readings: DictionaryPageState.readings(
                        [DictionaryEntry(simplified: "银行", traditional: "銀行", pinyin: "yínháng", isPreferred: true, senses: ["bank"])],
                        first: "yín háng"
                    ),
                    characters: [
                        .init(hanzi: "银", pinyin: "yín", gloss: "silver"),
                        .init(hanzi: "行", pinyin: "xíng", gloss: "to walk, to go, to travel"),
                    ]
                ),
                words: []
            ),
            onAction: { _ in }
        )
    }
}
