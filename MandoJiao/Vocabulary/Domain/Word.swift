import Foundation

/// A library entry with its mistake history.
nonisolated struct Word: Identifiable, Hashable, Sendable {
    let id: UUID
    let english: String
    let hanzi: String
    let pinyin: String
    let missCount: Int
    let lastMissedAt: Date?
    let createdAt: Date

    init(
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

    var isUsable: Bool {
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var pair: WordPair {
        WordPair(id: id, english: english, hanzi: hanzi, pinyin: pinyin)
    }

    /// Case-insensitive on English and pinyin, exact on Hanzi.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return english.lowercased().contains(query)
            || hanzi.contains(query)
            || pinyin.lowercased().contains(query)
    }
}

nonisolated extension Array where Element == Word {
    var pairs: [WordPair] { filter(\.isUsable).map(\.pair) }
}
