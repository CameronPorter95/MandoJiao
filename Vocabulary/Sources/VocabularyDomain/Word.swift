import Foundation

/// A library entry with its mistake history.
public nonisolated struct Word: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// In the learner's order. The first is the headline, shown on tiles and prompts.
    public let meanings: [String]
    public let hanzi: String
    public let pinyin: String
    public let missCount: Int
    public let lastMissedAt: Date?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        meanings: [String],
        hanzi: String,
        pinyin: String = "",
        missCount: Int = 0,
        lastMissedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.meanings = meanings
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.missCount = missCount
        self.lastMissedAt = lastMissedAt
        self.createdAt = createdAt
    }

    /// One meaning, for a word that has only the one.
    public init(
        id: UUID = UUID(),
        english: String,
        hanzi: String,
        pinyin: String = "",
        missCount: Int = 0,
        lastMissedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.init(
            id: id, meanings: english.isEmpty ? [] : [english], hanzi: hanzi, pinyin: pinyin,
            missCount: missCount, lastMissedAt: lastMissedAt, createdAt: createdAt
        )
    }

    /// The headline, as saved.
    public var english: String { meanings.first ?? "" }

    public var isUsable: Bool {
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Meanings made short for a lesson, the headline first.
    public var pair: WordPair {
        let meanings = self.meanings.map { Gloss.plain($0) }
        return WordPair(
            id: id,
            english: meanings.first ?? "",
            hanzi: hanzi,
            pinyin: pinyin,
            otherMeanings: Array(meanings.dropFirst())
        )
    }

    /// Read as the dictionary reads a query: Hanzi exactly, otherwise any meaning ignoring
    /// case, or pinyin ignoring tones and spaces, so "shui3" and "yin hang" find 水 and 银行.
    public func matches(_ query: String) -> Bool {
        let query = SearchQuery(query)
        guard !query.isEmpty else { return true }
        if query.isHanzi { return hanzi.contains(query.text) }
        return meanings.contains { $0.lowercased().contains(query.english) }
            || query.pinyin.map { SearchQuery.toneless(pinyin).contains($0) } ?? false
    }
}

public nonisolated extension Array where Element == Word {
    var pairs: [WordPair] { filter(\.isUsable).map(\.pair) }
}
