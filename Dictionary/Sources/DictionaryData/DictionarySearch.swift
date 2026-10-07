import DictionaryDomain
import Foundation

/// Every entry of the dictionary made searchable by Hanzi, by pinyin with or without tones,
/// and by English. Built once, on the first search, since most sessions never search.
nonisolated struct DictionarySearch: Sendable {
    private struct Record: Sendable {
        let line: Substring
        let simplified: String
        let traditional: String
        let pinyin: PinyinSpelling
        /// Each sense's glosses, asides dropped and lowercased: "to walk, to go" is two.
        let glosses: [[String]]
        let isPreferred: Bool
        /// The HSK headline this line carries, if any.
        let headline: String?
        /// Its HSK frequency rank, lower being commoner, when it is an HSK word in the reading
        /// HSK gives it. CC-CEDICT says nothing of frequency.
        let frequency: Int?
        /// How many headwords hold its rarest character, a weaker stand-in for words HSK
        /// does not have.
        let commonness: Int
    }

    private let records: [Record]

    /// An HSK word's headline is matched as its first sense, as the dictionary shows it,
    /// so "at" finds 在, and its HSK rank orders it among the other matches.
    init(_ index: BundledDictionary.Index, headlines: HSKHeadlines = HSKHeadlines([])) {
        var containing: [Character: Int] = [:]
        for hanzi in index.lines.keys {
            for character in Set(hanzi) { containing[character, default: 0] += 1 }
        }
        let entries = index.lines.values.flatMap { lines -> [(Substring, DictionaryEntry, HSKHeadlines.Word?)] in
            let parsed = lines.compactMap { line in BundledDictionary.Index.entry(line).map { (line, $0) } }
            let applied = headlines.applied(to: parsed.map(\.1))
            let carriers = headlines.carriers(among: parsed.map(\.1))
            return parsed.indices.map { (parsed[$0].0, applied[$0], carriers[$0]) }
        }
        records = entries.map { line, entry, hsk in
            Record(
                line: line,
                simplified: entry.simplified,
                traditional: entry.traditional,
                pinyin: PinyinSpelling(entry.pinyin),
                glosses: entry.senses.map(Self.glosses),
                isPreferred: entry.isPreferred,
                headline: hsk?.headline,
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
    func results(for query: String, limit: Int) -> [DictionarySearchResult] {
        let query = SearchQuery(query)
        guard !query.isEmpty else { return [] }
        let rank: (Record) -> Rank?
        if query.isHanzi {
            rank = { Self.hanziRank($0, query.text) }
        } else {
            rank = { record in
                [query.pinyin.flatMap { Self.pinyinRank(record, $0) }, Self.englishRank(record, query.english)]
                    .compactMap { $0 }.min()
            }
        }
        // CC-CEDICT has some headwords twice in one reading, differing only in their
        // traditional form or senses. The page shows both, so a result need only lead there.
        let ranked = records
            .compactMap { record in rank(record).map { (record, $0) } }
            .sorted { $0.1 < $1.1 }
        var seen = Set<String>()
        var results: [DictionarySearchResult] = []
        for (record, _) in ranked {
            guard results.count < limit else { break }
            guard let entry = BundledDictionary.Index.entry(record.line),
                  seen.insert("\(entry.simplified)\t\(entry.pinyin.lowercased())").inserted
            else { continue }
            results.append(DictionarySearchResult(entry: entry, headline: record.headline))
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

    private static func pinyinRank(_ record: Record, _ query: PinyinSpelling) -> Rank? {
        if record.pinyin.isSpelt(as: query) { return rank(record, match: 0) }
        if record.pinyin.hasPrefix(query) { return rank(record, match: 3) }
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
}
