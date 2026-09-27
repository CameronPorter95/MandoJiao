import Foundation
import VocabularyDomain

/// Every headword the lexicon knows, keyed by simplified Hanzi.
nonisolated protocol LexiconSource: Sendable {
    func entries() async throws -> [String: WordSuggestion]
}

nonisolated enum LexiconSourceError: Error, Equatable {
    case missingResource
    case unreadable
}

/// Reads `Lexicon.tsv`, which `Tools/MakeLexicon` builds from CC-CEDICT.
nonisolated struct BundledLexiconSource: LexiconSource {
    func entries() async throws -> [String: WordSuggestion] {
        guard let url = Bundle.module.url(forResource: "Lexicon", withExtension: "tsv") else {
            throw LexiconSourceError.missingResource
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { throw LexiconSourceError.unreadable }
        return Self.parse(text)
    }

    static func parse(_ text: String) -> [String: WordSuggestion] {
        var entries: [String: WordSuggestion] = [:]
        entries.reserveCapacity(130_000)
        for line in text.utf8.split(separator: UInt8(ascii: "\n")) where line.first != UInt8(ascii: "#") {
            let fields = line.split(separator: UInt8(ascii: "\t"), maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { continue }
            let hanzi = String(decoding: fields[0], as: UTF8.self)
            entries[hanzi] = WordSuggestion(
                hanzi: hanzi,
                pinyin: String(decoding: fields[1], as: UTF8.self),
                english: String(decoding: fields[2], as: UTF8.self)
            )
        }
        return entries
    }
}
