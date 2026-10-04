import Foundation

/// A dictionary page to open: some Hanzi, and the reading to put first, such as a library
/// word's or the one a longer headword gives a character.
public struct DictionaryHeadword: Hashable, Identifiable, Sendable {
    public let hanzi: String
    public let pinyin: String?

    public var id: Self { self }

    public init(hanzi: String, pinyin: String? = nil) {
        self.hanzi = hanzi
        self.pinyin = pinyin
    }
}
