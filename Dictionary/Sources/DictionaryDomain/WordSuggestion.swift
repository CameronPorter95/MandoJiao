import Foundation

/// What the lexicon suggests for some Hanzi. Either field may be empty.
public nonisolated struct WordSuggestion: Equatable, Sendable {
    public let hanzi: String
    public let pinyin: String
    public let english: String

    public init(hanzi: String, pinyin: String, english: String) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
    }
}
