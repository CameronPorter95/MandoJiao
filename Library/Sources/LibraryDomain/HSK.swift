import DictionaryDomain
import Foundation

/// How HSK words become folders and decks: HSK › HSK 1 › HSK 1 · 1, most common words first.
public nonisolated enum HSK {
    public static let levels = HSKLevel.all
    /// The most a deck holds. A level is split evenly, so no deck is left with a few words.
    public static let deckSize = 50

    public static let rootKey = "hsk"
    public static func levelKey(_ level: Int) -> String { "hsk/\(level)" }
    public static func deckKey(_ level: Int, _ number: Int) -> String { "hsk/\(level)/\(number)" }

    public static func levelName(_ level: Int) -> String { HSKLevel.name(level) }
    public static func deckName(_ level: Int, _ number: Int) -> String { "\(levelName(level)) · \(number)" }

    public static func deckCount(forWords count: Int) -> Int {
        max(1, Int((Double(count) / Double(deckSize)).rounded(.up)))
    }

    /// `words` are the level's words, in any order. The HSK folder goes last at the top level.
    public static func plan(level: Int, words: [HSKWord], topLevelFolders: Int) -> BuiltInPlan {
        // Stable, so a character's second reading stays after its main one, as the list has it.
        let ordered = words.enumerated().filter { $0.element.level == level }
            .sorted { ($0.element.rank, $0.element.hanzi, $0.offset) < ($1.element.rank, $1.element.hanzi, $1.offset) }
            .map(\.element)
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
