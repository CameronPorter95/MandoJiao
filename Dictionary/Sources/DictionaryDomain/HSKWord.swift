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
    /// True when every meaning was chosen by hand, so they stand in for the dictionary's
    /// senses of this reading rather than heading them: 最 is "(the) most ..." and "best or
    /// most extreme example", without CC-CEDICT's longer sense that repeats the first.
    public let replacesSenses: Bool

    public init(level: Int, rank: Int, hanzi: String, pinyin: String, meanings: [String], replacesSenses: Bool = false) {
        self.level = level
        self.rank = rank
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meanings = meanings
        self.replacesSenses = replacesSenses
    }
}

/// The syllabus's levels, as the dictionary badges a reading and the library names a folder.
public nonisolated enum HSKLevel {
    /// 7 stands for levels 7 to 9, which the syllabus lists together.
    public static let all = 1...7

    public static func name(_ level: Int) -> String { level == 7 ? "HSK 7-9" : "HSK \(level)" }
}

/// The bundled syllabus.
public nonisolated protocol HSKRepository: Sendable {
    func words() async throws -> [HSKWord]
}
