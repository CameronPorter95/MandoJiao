import Foundation

/// One reading of a headword in the dictionary, with every sense it has. Never edited.
public nonisolated struct DictionaryEntry: Hashable, Sendable {
    public let simplified: String
    /// Several, comma separated, where CC-CEDICT gives the reading more than one: "為, 爲".
    public let traditional: String
    public let pinyin: String
    /// The reading suggestions use when a headword has several.
    public let isPreferred: Bool
    /// As the dictionary gives them, asides included, most common first.
    public let senses: [String]
    /// The HSK level of the syllabus word with this reading, 7 for levels 7 to 9. Nil for a
    /// reading not in the syllabus, as 长 zhǎng would be if only cháng were.
    public let hskLevel: Int?

    public init(simplified: String, traditional: String, pinyin: String, isPreferred: Bool, senses: [String], hskLevel: Int? = nil) {
        self.simplified = simplified
        self.traditional = traditional
        self.pinyin = pinyin
        self.isPreferred = isPreferred
        self.senses = senses
        self.hskLevel = hskLevel
    }
}

/// A headword search found, with the headline an HSK word's library copy would have.
public nonisolated struct DictionarySearchResult: Hashable, Sendable {
    public let entry: DictionaryEntry
    /// Chosen for common HSK words where the dictionary's first sense is not the everyday
    /// one, and what a result row shows: 在 is "at, in", not "to exist, to be alive".
    public let headline: String?

    public init(entry: DictionaryEntry, headline: String? = nil) {
        self.entry = entry
        self.headline = headline
    }

    public var simplified: String { entry.simplified }
    public var pinyin: String { entry.pinyin }

    /// The headline, else the dictionary's first sense, made short for a row.
    public var summary: String? { (headline ?? entry.senses.first).map { Gloss.plain($0) } }
}

public nonisolated protocol DictionaryRepository: Sendable {
    /// Every reading of the headword, the preferred one first. Empty when it is not a headword.
    func entries(forHanzi hanzi: String) async throws -> [DictionaryEntry]
    /// Headwords matching Hanzi, pinyin with or without tones, or English, best first.
    func search(_ query: String, limit: Int) async throws -> [DictionarySearchResult]
    /// Readies `search`, so the first query does not wait for it. A failure is left for that
    /// query to report.
    func prepareSearch() async
}
