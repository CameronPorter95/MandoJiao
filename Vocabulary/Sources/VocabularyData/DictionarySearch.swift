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
        /// Its HSK frequency rank, lower being commoner, when it is an HSK word in the reading
        /// HSK gives it. CC-CEDICT says nothing of frequency.
        let frequency: Int?
        /// How many headwords hold its rarest character, a weaker stand-in for words HSK
        /// does not have.
        let commonness: Int
    }

    private let records: [Record]

    /// `frequencies` are each HSK word's reading, rank and headline, by Hanzi. The headline is
    /// matched as if it were the entry's first sense, since for common words it was chosen by
    /// hand where CC-CEDICT's first sense is not the everyday one: "at" finds 在 by it.
    init(_ index: BundledDictionary.Index, frequencies: [String: (pinyin: String, rank: Int, headline: String)] = [:]) {
        var containing: [Character: Int] = [:]
        for hanzi in index.lines.keys {
            for character in Set(hanzi) { containing[character, default: 0] += 1 }
        }
        let entries = index.lines.values.flatMap { $0 }.compactMap { line in BundledDictionary.Index.entry(line).map { (line, $0) } }
        // An HSK word's reading is spelt as the dictionary spells it, so it must match exactly:
        // without tones and case, 钱's surname Qián and 告诉's gàosù, "to press charges", took
        // the everyday word's rank. Of lines in that reading, the headline goes to the one
        // holding it, like 周's "week" rather than its "to make a circuit", else the preferred.
        let holding = Set(entries.compactMap { _, entry in
            frequencies[entry.simplified].flatMap { $0.pinyin == entry.pinyin && entry.senses.contains($0.headline) ? entry.simplified : nil }
        })
        records = entries.map { line, entry in
            let hsk = frequencies[entry.simplified].flatMap { hsk in
                hsk.pinyin == entry.pinyin
                    && (entry.senses.contains(hsk.headline) || (!holding.contains(entry.simplified) && entry.isPreferred)) ? hsk : nil
            }
            // First, even where it is a later sense, since a first sense outranks the rest.
            let senses = hsk.map { hsk in [hsk.headline] + entry.senses.filter { $0 != hsk.headline } } ?? entry.senses
            return Record(
                line: line,
                simplified: entry.simplified,
                traditional: entry.traditional,
                toneless: Self.toneless(entry.pinyin),
                glosses: senses.map(Self.glosses),
                isPreferred: entry.isPreferred,
                frequency: hsk?.rank,
                // Characters outside the main block, like 㣟, are all rare.
                commonness: entry.simplified.unicodeScalars.allSatisfy { !(0x3400...0x4DBF).contains($0.value) && $0.value < 0x20000 }
                    ? entry.simplified.map { containing[$0] ?? 0 }.min() ?? 0
                    : -1
            )
        }
    }

    /// Best first: an exact match before a partial one, a match on a first sense before a
    /// later one, then HSK words by frequency before the rest, then shorter headwords, then
    /// commoner ones. An exact pinyin and an exact English match rank alike, so "you" is 你
    /// before 有 yǒu, frequency deciding.
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
        /// `Int.max` for a word HSK does not have.
        let frequency: Int
        let sense: Int
        let gloss: Int
        let length: Int
        let rarity: Int
        let notPreferred: Int
        let headword: String

        static func < (a: Rank, b: Rank) -> Bool {
            let ties = (a.length, a.rarity, a.notPreferred, a.headword)
            let others = (b.length, b.rarity, b.notPreferred, b.headword)
            // A first sense before a later one, so 喝's "to drink" is not beaten by the far
            // commoner 用's "(honorific) to eat or drink".
            let first = (a.match, a.sense < 3 ? 0 : 1, a.frequency, a.sense, a.gloss)
            let second = (b.match, b.sense < 3 ? 0 : 1, b.frequency, b.sense, b.gloss)
            return first != second ? first < second : ties < others
        }
    }

    private static func rank(_ record: Record, match: Int, sense: Int = 0, gloss: Int = 0) -> Rank {
        Rank(
            match: match, frequency: record.frequency ?? .max, sense: sense, gloss: gloss,
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
                    match = 0
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
