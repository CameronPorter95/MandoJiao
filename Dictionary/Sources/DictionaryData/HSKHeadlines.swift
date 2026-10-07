import DictionaryDomain
import Foundation

/// Each HSK word's headline, put first among its reading's senses wherever the dictionary is
/// read, so the dictionary and a library word agree, and its level marked on that reading. For common words it was chosen by hand
/// (Tools/MakeHSK/headlines.tsv) where CC-CEDICT's first sense is not the everyday one, and
/// is sometimes not a CC-CEDICT sense at all: 在 heads with "at, in".
nonisolated struct HSKHeadlines: Sendable {
    struct Word: Sendable {
        let pinyin: String
        let level: Int
        let rank: Int
        let headline: String
        /// Every meaning, where they were all chosen by hand and replace the dictionary's.
        let meanings: [String]?
    }

    /// Each character's readings, the main one first: 长 is cháng and zhǎng.
    let words: [String: [Word]]

    init(_ hsk: [HSKWord]) {
        var words: [String: [Word]] = [:]
        for word in hsk {
            guard let headline = word.meanings.first else { continue }
            words[word.hanzi, default: []].append(Word(
                pinyin: word.pinyin, level: word.level, rank: word.rank, headline: headline,
                meanings: word.replacesSenses ? word.meanings : nil
            ))
        }
        self.words = words
    }

    /// Read once. Without the HSK list the dictionary reads as CC-CEDICT alone.
    static let bundled = HSKHeadlines((try? BundledHSK.words()) ?? [])

    /// Which of one headword's entries carries each of its HSK readings' headlines. The
    /// reading must match exactly: without tones and case, 钱's surname Qián and 告诉's gàosù,
    /// "to press charges", took the everyday word's. Of lines in that reading, the one
    /// holding the headline, like 周's "week" rather than its "to make a circuit", else the
    /// preferred.
    func carriers(among entries: [DictionaryEntry]) -> [Int: Word] {
        guard let hanzi = entries.first?.simplified, let readings = words[hanzi] else { return [:] }
        var carriers: [Int: Word] = [:]
        for word in readings {
            let reading = entries.indices.filter { entries[$0].pinyin == word.pinyin && carriers[$0] == nil }
            guard let index = reading.first(where: { entries[$0].senses.contains(word.headline) })
                ?? reading.first(where: { entries[$0].isPreferred })
                ?? reading.first
            else { continue }
            carriers[index] = word
        }
        return carriers
    }

    /// Each carrier's headline first, and any sense it already says in full dropped: 才's
    /// "only then, just; ability, talent" makes its later "ability, talent" redundant.
    /// Compared part by part, so 给's "to" is not lost inside "to give".
    func applied(to entries: [DictionaryEntry]) -> [DictionaryEntry] {
        var result = entries
        for (index, word) in carriers(among: entries) {
            let entry = entries[index]
            let said = Self.parts(word.headline)
            result[index] = DictionaryEntry(
                simplified: entry.simplified,
                traditional: entry.traditional,
                pinyin: entry.pinyin,
                isPreferred: entry.isPreferred,
                senses: word.meanings
                    ?? [word.headline] + entry.senses.filter { $0 != word.headline && !Self.parts($0).isSubset(of: said) },
                hskLevel: word.level
            )
        }
        return result
    }

    private static func parts(_ text: String) -> Set<String> {
        Set(text.split(whereSeparator: { ",;".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) })
    }
}
