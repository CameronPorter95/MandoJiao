import Foundation
import VocabularyDomain

/// Every headword the lexicon knows, looked up by simplified Hanzi.
nonisolated protocol LexiconSource: Sendable {
    func entries() async throws -> LexiconTable
}

nonisolated struct LexiconTable: Sendable {
    /// In characters, so a phrase is only ever split into pieces this long or shorter.
    let longestHeadword: Int
    let suggestion: @Sendable (String) -> WordSuggestion?

    init(longestHeadword: Int, suggestion: @escaping @Sendable (String) -> WordSuggestion?) {
        self.longestHeadword = longestHeadword
        self.suggestion = suggestion
    }

    init(_ entries: [String: WordSuggestion]) {
        self.init(longestHeadword: entries.keys.map(\.count).max() ?? 0, suggestion: { entries[$0] })
    }
}

nonisolated enum DictionarySourceError: Error, Equatable {
    case missingResource
    case unreadable
}

/// `Dictionary.tsv`, which `Tools/MakeDictionary` builds from CC-CEDICT, read once and shared
/// by the dictionary and the lexicon. Only each line's headword is read up front; an entry's
/// fields are split when it is looked up, since almost none ever are.
actor BundledDictionary {
    static let shared = BundledDictionary()

    nonisolated struct Index: Sendable {
        let lines: [String: [Substring]]
        let longestHeadword: Int

        /// The preferred reading first.
        func entries(forHanzi hanzi: String) -> [DictionaryEntry] {
            (lines[hanzi] ?? []).compactMap(Self.entry).sorted { $0.isPreferred && !$1.isPreferred }
        }

        static func entry(_ line: Substring) -> DictionaryEntry? {
            let fields = line.split(separator: "\t", maxSplits: 4, omittingEmptySubsequences: false)
            guard fields.count == 5 else { return nil }
            return DictionaryEntry(
                simplified: String(fields[0]),
                traditional: String(fields[1]),
                pinyin: String(fields[2]),
                isPreferred: fields[3] == "1",
                senses: fields[4].split(separator: "\u{1F}").map(String.init)
            )
        }
    }

    private var loading: Task<Index, any Error>?
    private var searching: Task<DictionarySearch, any Error>?

    func search() async throws -> DictionarySearch {
        if searching == nil {
            searching = Task.detached { [self] in
                // Without the HSK list search still works, only ranked less well.
                let hsk = (try? BundledHSK.words()) ?? []
                let frequencies = Dictionary(
                    hsk.map { ($0.hanzi, (pinyin: $0.pinyin, rank: $0.rank, headline: $0.meanings.first ?? "")) },
                    uniquingKeysWith: { first, _ in first }
                )
                return DictionarySearch(try await index(), frequencies: frequencies)
            }
        }
        do {
            return try await searching!.value
        } catch {
            searching = nil
            throw error
        }
    }

    func index() async throws -> Index {
        if loading == nil {
            loading = Task.detached {
                guard let url = Bundle.module.url(forResource: "Dictionary", withExtension: "tsv") else {
                    throw DictionarySourceError.missingResource
                }
                guard let text = String(data: try Data(contentsOf: url), encoding: .utf8) else {
                    throw DictionarySourceError.unreadable
                }
                return Self.index(text)
            }
        }
        do {
            return try await loading!.value
        } catch {
            loading = nil
            throw error
        }
    }

    nonisolated static func index(_ text: String) -> Index {
        var lines: [String: [Substring]] = [:]
        lines.reserveCapacity(125_000)
        var longest = 0
        for bytes in text.utf8.split(separator: UInt8(ascii: "\n")) where bytes.first != UInt8(ascii: "#") {
            guard let tab = bytes.firstIndex(of: UInt8(ascii: "\t")) else { continue }
            let hanzi = String(Substring(bytes[..<tab]))
            longest = max(longest, hanzi.count)
            lines[hanzi, default: []].append(Substring(bytes))
        }
        return Index(lines: lines, longestHeadword: longest)
    }
}

/// Each headword's preferred reading, with its first sense made short.
nonisolated struct DictionaryLexiconSource: LexiconSource {
    func entries() async throws -> LexiconTable {
        let index = try await BundledDictionary.shared.index()
        return LexiconTable(longestHeadword: index.longestHeadword) { hanzi in
            index.entries(forHanzi: hanzi).first.map {
                WordSuggestion(hanzi: $0.simplified, pinyin: $0.pinyin, english: $0.senses.first.map { Gloss.plain($0) } ?? "")
            }
        }
    }
}
