import Foundation
import VocabularyDomain

/// Every entry of the dictionary made searchable by Hanzi, by pinyin without tones, and by
/// English. Built once, on the first search, since most sessions never search.
nonisolated struct DictionarySearch: Sendable {
    private struct Record: Sendable {
        let line: Substring
        let simplified: String
        let traditional: String
        let toneless: String
        /// Each sense's glosses, asides dropped and lowercased: "to walk, to go" is two.
        let glosses: [[String]]
        let isPreferred: Bool
        /// How many headwords hold its rarest character, as a stand-in for how common it
        /// is, which CC-CEDICT does not say.
        let commonness: Int
    }

    private let records: [Record]

    init(_ index: BundledDictionary.Index) {
        var containing: [Character: Int] = [:]
        for hanzi in index.lines.keys {
            for character in Set(hanzi) { containing[character, default: 0] += 1 }
        }
        records = index.lines.values.flatMap { $0 }.compactMap { line in
            guard let entry = BundledDictionary.Index.entry(line) else { return nil }
            return Record(
                line: line,
                simplified: entry.simplified,
                traditional: entry.traditional,
                toneless: Self.toneless(entry.pinyin),
                glosses: entry.senses.map(Self.glosses),
                isPreferred: entry.isPreferred,
                // Characters outside the main block, like 㣟, are all rare.
                commonness: entry.simplified.unicodeScalars.allSatisfy { !(0x3400...0x4DBF).contains($0.value) && $0.value < 0x20000 }
                    ? entry.simplified.map { containing[$0] ?? 0 }.min() ?? 0
                    : -1
            )
        }
    }

    /// Best first: an exact match before a partial one, then shorter headwords, then
    /// commoner ones.
    func results(for query: String, limit: Int) -> [DictionaryEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let rank: (Record) -> Rank?
        if query.unicodeScalars.contains(where: Self.isHan) {
            rank = { Self.hanziRank($0, query) }
        } else {
            let english = query.lowercased()
            let pinyin = Self.isPinyin(query) ? Self.toneless(query) : nil
            rank = { record in
                [pinyin.flatMap { Self.pinyinRank(record, $0) }, Self.englishRank(record, english)]
                    .compactMap { $0 }.min()
            }
        }
        // CC-CEDICT has some headwords twice in one reading, differing only in their
        // traditional form or senses. The page shows both, so a result need only lead there.
        let ranked = records
            .compactMap { record in rank(record).map { (record, $0) } }
            .sorted { $0.1 < $1.1 }
        var seen = Set<String>()
        var results: [DictionaryEntry] = []
        for (record, _) in ranked {
            guard results.count < limit else { break }
            guard let entry = BundledDictionary.Index.entry(record.line),
                  seen.insert("\(entry.simplified)\t\(entry.pinyin)").inserted
            else { continue }
            results.append(entry)
        }
        return results
    }

    private struct Rank: Comparable {
        let match: Int
        let sense: Int
        let gloss: Int
        let length: Int
        let rarity: Int
        let notPreferred: Int
        let headword: String

        static func < (a: Rank, b: Rank) -> Bool {
            let ties = (a.length, a.rarity, a.notPreferred, a.headword)
            let others = (b.length, b.rarity, b.notPreferred, b.headword)
            return (a.match, a.sense, a.gloss) != (b.match, b.sense, b.gloss)
                ? (a.match, a.sense, a.gloss) < (b.match, b.sense, b.gloss)
                : ties < others
        }
    }

    private static func rank(_ record: Record, match: Int, sense: Int = 0, gloss: Int = 0) -> Rank {
        Rank(
            match: match, sense: sense, gloss: gloss,
            length: record.simplified.count, rarity: -record.commonness,
            notPreferred: record.isPreferred ? 0 : 1, headword: record.simplified
        )
    }

    private static func hanziRank(_ record: Record, _ query: String) -> Rank? {
        let forms = [record.simplified, record.traditional]
        if forms.contains(query) { return rank(record, match: 0) }
        if forms.contains(where: { $0.hasPrefix(query) }) { return rank(record, match: 1) }
        if forms.contains(where: { $0.contains(query) }) { return rank(record, match: 2) }
        return nil
    }

    private static func pinyinRank(_ record: Record, _ query: String) -> Rank? {
        guard !query.isEmpty else { return nil }
        if record.toneless == query { return rank(record, match: 0) }
        if record.toneless.hasPrefix(query) { return rank(record, match: 3) }
        return nil
    }

    /// A whole gloss, or one that is the query as a verb, before a gloss merely holding it.
    private static func englishRank(_ record: Record, _ query: String) -> Rank? {
        var best: Rank?
        let padded = " \(query) "
        for (sense, glosses) in record.glosses.enumerated() {
            for (index, gloss) in glosses.enumerated() {
                let match: Int
                if gloss == query || gloss == "to \(query)" {
                    match = 1
                } else if " \(gloss) ".contains(padded) {
                    match = 4
                } else {
                    continue
                }
                let candidate = rank(record, match: match, sense: sense, gloss: index)
                if best.map({ candidate < $0 }) ?? true { best = candidate }
            }
        }
        return best
    }

    private static func glosses(_ sense: String) -> [String] {
        var depth = 0
        var kept = ""
        for character in sense.lowercased() {
            switch character {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            default: if depth == 0 { kept.append(character.isLetter || character.isNumber || character == "," || character == "'" ? character : " ") }
            }
        }
        return kept.split(separator: ",")
            .map { $0.split(separator: " ").joined(separator: " ") }
            .filter { !$0.isEmpty }
    }

    /// Letters only: "Yín háng", "yin2 hang2" and "yinhang" are all "yinhang".
    static func toneless(_ pinyin: String) -> String {
        pinyin.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .filter { $0.isLetter }
    }

    private static func isPinyin(_ query: String) -> Bool {
        query.allSatisfy { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" }
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x9FFF).contains(scalar.value) || (0x20000...0x2FFFF).contains(scalar.value)
    }
}
