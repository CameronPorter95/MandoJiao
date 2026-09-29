import Foundation

/// What a search box holds, read as the dictionary and the library both read it: Hanzi if it
/// has any, otherwise English and, when it could be, pinyin with spaces ignored and tones
/// ignored unless it writes them.
public nonisolated struct SearchQuery: Hashable, Sendable {
    /// Trimmed, for matching Hanzi.
    public let text: String
    public let isHanzi: Bool
    /// Lowercased, for matching English.
    public let english: String
    /// For matching pinyin, with any tones it writes. Nil for Hanzi, for text pinyin never
    /// holds, and for text with no letters, like "3".
    public let pinyin: PinyinSpelling?

    public init(_ raw: String) {
        text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        isHanzi = text.unicodeScalars.contains(where: Self.isHan)
        english = text.lowercased()
        let spelling = PinyinSpelling(text)
        pinyin = !isHanzi && Self.isPinyin(text) && !spelling.letters.isEmpty ? spelling : nil
    }

    public var isEmpty: Bool { text.isEmpty }

    /// Letters only: "Yín háng", "yin2 hang2" and "yinhang" are all "yinhang".
    public static func toneless(_ pinyin: String) -> String {
        pinyin.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .filter { $0.isLetter }
    }

    private static func isPinyin(_ text: String) -> Bool {
        text.allSatisfy { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" }
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x9FFF).contains(scalar.value) || (0x20000...0x2FFFF).contains(scalar.value)
    }
}
