import Foundation

/// One word of the HSK 3.0 syllabus, 2025 revision.
public nonisolated struct HSKWord: Equatable, Sendable {
    /// 1 to 6, and 7 for levels 7 to 9, which the syllabus lists together.
    public let level: Int
    /// Lower is more common.
    public let rank: Int
    public let hanzi: String
    public let pinyin: String
    /// The dictionary's senses for this reading, as a word's meanings are: the first is the
    /// headline.
    public let meanings: [String]

    public init(level: Int, rank: Int, hanzi: String, pinyin: String, meanings: [String]) {
        self.level = level
        self.rank = rank
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meanings = meanings
    }
}

/// How HSK words become folders and decks: HSK › HSK 1 › HSK 1 · 1, most common words first.
public nonisolated enum HSK {
    public static let levels = 1...7
    /// The most a deck holds. A level is split evenly, so no deck is left with a few words.
    public static let deckSize = 50

    public static let rootKey = "hsk"
    public static func levelKey(_ level: Int) -> String { "hsk/\(level)" }
    public static func deckKey(_ level: Int, _ number: Int) -> String { "hsk/\(level)/\(number)" }

    public static func levelName(_ level: Int) -> String { level == 7 ? "HSK 7-9" : "HSK \(level)" }
    public static func deckName(_ level: Int, _ number: Int) -> String { "\(levelName(level)) · \(number)" }

    public static func deckCount(forWords count: Int) -> Int {
        max(1, Int((Double(count) / Double(deckSize)).rounded(.up)))
    }

    /// `words` are the level's words, in any order. The HSK folder goes last at the top level.
    public static func plan(level: Int, words: [HSKWord], topLevelFolders: Int) -> BuiltInPlan {
        let ordered = words.filter { $0.level == level }.sorted { ($0.rank, $0.hanzi) < ($1.rank, $1.hanzi) }
        let count = deckCount(forWords: ordered.count)
        var decks: [BuiltInPlan.Deck] = []
        var start = 0
        for index in 0..<count {
            let size = ordered.count / count + (index < ordered.count % count ? 1 : 0)
            let chunk = ordered[start..<start + size]
            start += size
            decks.append(BuiltInPlan.Deck(
                key: deckKey(level, index + 1),
                name: deckName(level, index + 1),
                folderKey: levelKey(level),
                position: index,
                words: chunk.map { WordDraft(meanings: $0.meanings, hanzi: $0.hanzi, pinyin: $0.pinyin) }
            ))
        }
        return BuiltInPlan(
            folders: [
                BuiltInPlan.Folder(key: rootKey, name: "HSK", parentKey: nil, position: topLevelFolders),
                BuiltInPlan.Folder(key: levelKey(level), name: levelName(level), parentKey: rootKey, position: level - 1),
            ],
            decks: decks
        )
    }
}

/// The bundled syllabus.
public nonisolated protocol HSKRepository: Sendable {
    func words() async throws -> [HSKWord]
}
