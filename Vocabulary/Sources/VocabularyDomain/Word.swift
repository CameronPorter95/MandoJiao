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
    public let memory: WordMemory

    public init(
        id: UUID = UUID(),
        meanings: [String],
        hanzi: String,
        pinyin: String = "",
        missCount: Int = 0,
        lastMissedAt: Date? = nil,
        createdAt: Date = .now,
        memory: WordMemory = .new
    ) {
        self.id = id
        self.meanings = meanings
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.missCount = missCount
        self.lastMissedAt = lastMissedAt
        self.createdAt = createdAt
        self.memory = memory
    }

    /// One meaning, for a word that has only the one.
    public init(
        id: UUID = UUID(),
        english: String,
        hanzi: String,
        pinyin: String = "",
        missCount: Int = 0,
        lastMissedAt: Date? = nil,
        createdAt: Date = .now,
        memory: WordMemory = .new
    ) {
        self.init(
            id: id, meanings: english.isEmpty ? [] : [english], hanzi: hanzi, pinyin: pinyin,
            missCount: missCount, lastMissedAt: lastMissedAt, createdAt: createdAt, memory: memory
        )
    }

    public var isLearnt: Bool { memory.isLearnt }

    public func band(at now: Date) -> StrengthBand { memory.band(at: now) }

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
    /// case, or pinyin ignoring spaces and any tone not written, so "shui3" and "yin hang"
    /// find 水 and 银行, and "shui2" does not find 水.
    public func matches(_ query: String) -> Bool {
        matches(SearchQuery(query))
    }

    /// For a query read once and matched against many words.
    public func matches(_ query: SearchQuery) -> Bool {
        guard !query.isEmpty else { return true }
        if query.isHanzi { return hanzi.contains(query.text) }
        return meanings.contains { $0.lowercased().contains(query.english) }
            || query.pinyin.map { PinyinSpelling(pinyin).contains($0) } ?? false
    }

    /// Whether this word is that reading of its Hanzi, however its pinyin was typed:
    /// "yin2 hang2" is yínháng. A word saved without pinyin is no reading in particular.
    public func isReading(of entry: DictionaryEntry) -> Bool {
        hanzi == entry.simplified && !pinyin.isEmpty && Self.spelling(pinyin) == Self.spelling(entry.pinyin)
    }

    /// The letters, and the tones in the order written, so marks and numbers compare alike.
    /// A 5 for the neutral tone is dropped, as a neutral tone is written with no mark.
    private static func spelling(_ pinyin: String) -> (letters: String, tones: [Int]) {
        var letters = String.UnicodeScalarView()
        var tones: [Int] = []
        for scalar in pinyin.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x304: tones.append(1)
            case 0x301: tones.append(2)
            case 0x30C: tones.append(3)
            case 0x300: tones.append(4)
            case 0x31...0x34: tones.append(Int(scalar.value) - 0x30)
            case 0x300...0x36F: continue
            default: if scalar.properties.isAlphabetic { letters.append(scalar) }
            }
        }
        return (String(letters), tones)
    }
}

public nonisolated extension Array where Element == Word {
    var pairs: [WordPair] { filter(\.isUsable).map(\.pair) }
}
