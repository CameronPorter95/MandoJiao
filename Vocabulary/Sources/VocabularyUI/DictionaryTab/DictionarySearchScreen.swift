import CoreDesignSystem
import CoreUI
import SwiftUI
import VocabularyDomain

struct DictionarySearchScreen: View {
    let state: DictionarySearchState
    let onAction: (DictionarySearchAction) -> Void

    var body: some View {
        List {
            if case .found(let entries) = state.results {
                ForEach(entries, id: \.self) { entry in
                    NavigationLink(value: DictionaryHeadword(hanzi: entry.simplified, pinyin: entry.pinyin)) {
                        DictionaryResultRow(entry: entry)
                    }
                }
            }
        }
        .overlay {
            switch state.results {
            case .none:
                ContentUnavailableView(
                    "Search the dictionary",
                    systemImage: "character.book.closed",
                    description: Text("By Hanzi, by pinyin with or without tones, or by English. From CC-CEDICT.")
                )
            case .searching:
                ProgressView()
            case .found(let entries) where entries.isEmpty:
                ContentUnavailableView.search(text: state.query)
            case .found:
                EmptyView()
            case .failed:
                ContentUnavailableView(
                    "The dictionary could not be searched",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .searchField(initial: state.query, prompt: "银行, yinhang or bank") { onAction(.queryChanged($0)) }
        .neverAutocapitalize()
        // Autocorrect would turn pinyin into English words, and on return or clear it
        // writes its pending correction back into the field, so a cleared query came back.
        .autocorrectionDisabled()
        .navigationTitle("Dictionary")
    }
}

private struct DictionaryResultRow: View {
    let entry: DictionaryEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.simplified)
                .font(.system(size: 22, weight: .medium))
                .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.pinyin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.senses.first.map { Gloss.plain($0) } ?? "No meanings given")
                    .lineLimit(1)
                    .foregroundStyle(entry.senses.isEmpty ? .secondary : .primary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DictionarySearchScreen(
            state: DictionarySearchState(query: "bank", results: .found([
                DictionaryEntry(simplified: "银行", traditional: "銀行", pinyin: "yínháng", isPreferred: true, senses: ["bank"]),
                DictionaryEntry(simplified: "岸", traditional: "岸", pinyin: "àn", isPreferred: true, senses: ["bank, shore, beach, coast"]),
            ])),
            onAction: { _ in }
        )
    }
}
