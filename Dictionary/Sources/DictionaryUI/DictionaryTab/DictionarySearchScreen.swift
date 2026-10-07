import CoreDesignSystem
import CoreUI
import DictionaryDomain
import SwiftUI

struct DictionarySearchScreen: View {
    let state: DictionarySearchState
    let onAction: (DictionarySearchAction) -> Void

    var body: some View {
        List {
            if case .found(let entries) = state.results {
                ForEach(entries, id: \.self) { result in
                    let vocabulary = state.vocabulary(for: result)
                    NavigationLink(value: DictionaryHeadword(hanzi: result.simplified, pinyin: result.pinyin)) {
                        DictionaryResultRow(result: result, isSaved: vocabulary?.isSaved ?? false)
                    }
                    .swipeActions(edge: .leading) {
                        if let vocabulary {
                            Button {
                                onAction(.vocabularyTapped(result))
                            } label: {
                                if vocabulary.isSaved {
                                    Label("Edit", systemImage: "pencil")
                                } else {
                                    Label("Add", systemImage: "plus")
                                }
                            }
                            .tint(Theme.accent)
                        }
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
        .onAppear { onAction(.appeared) }
        .onDisappear { onAction(.disappeared) }
    }
}

private struct DictionaryResultRow: View {
    let result: DictionarySearchResult
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(result.simplified)
                .font(.system(size: 22, weight: .medium))
                .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.pinyin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.summary ?? "No meanings given")
                    .lineLimit(1)
                    .foregroundStyle(result.summary == nil ? .secondary : .primary)
            }
            if isSaved {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("In vocabulary")
            }
        }
    }
}

#Preview {
    NavigationStack {
        DictionarySearchScreen(
            state: DictionarySearchState(query: "bank", results: .found([
                DictionarySearchResult(entry: DictionaryEntry(simplified: "银行", traditional: "銀行", pinyin: "yínháng", isPreferred: true, senses: ["bank"])),
                DictionarySearchResult(entry: DictionaryEntry(simplified: "岸", traditional: "岸", pinyin: "àn", isPreferred: true, senses: ["bank, shore, beach, coast"])),
            ]), saved: [SavedReading(id: UUID(), hanzi: "银行", pinyin: "yínháng")]),
            onAction: { _ in }
        )
    }
}
