import Foundation

/// A library entry with its mistake history.
public nonisolated struct Word: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let english: String
    public let hanzi: String
    public let pinyin: String
    public let missCount: Int
    public let lastMissedAt: Date?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        english: String,
        hanzi: String,
        pinyin: String = "",
        missCount: Int = 0,
        lastMissedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.english = english
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.missCount = missCount
        self.lastMissedAt = lastMissedAt
        self.createdAt = createdAt
    }

    public var isUsable: Bool {
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var pair: WordPair {
        WordPair(id: id, english: english, hanzi: hanzi, pinyin: pinyin)
    }

    /// Case-insensitive on English and pinyin, exact on Hanzi.
    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return english.lowercased().contains(query)
            || hanzi.contains(query)
            || pinyin.lowercased().contains(query)
    }
}

public nonisolated extension Array where Element == Word {
    var pairs: [WordPair] { filter(\.isUsable).map(\.pair) }
}
