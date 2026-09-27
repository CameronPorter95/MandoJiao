import Foundation

/// A word as typed, before it is saved.
public nonisolated struct WordDraft: Equatable, Sendable {
    public var english = ""
    public var hanzi = ""
    public var pinyin = ""

    public init(english: String = "", hanzi: String = "", pinyin: String = "") {
        self.english = english
        self.hanzi = hanzi
        self.pinyin = pinyin
    }

    public var trimmed: WordDraft {
        WordDraft(
            english: english.trimmingCharacters(in: .whitespacesAndNewlines),
            hanzi: hanzi.trimmingCharacters(in: .whitespacesAndNewlines),
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// English and Hanzi are required; pinyin is optional.
    public var isComplete: Bool {
        let trimmed = trimmed
        return !trimmed.english.isEmpty && !trimmed.hanzi.isEmpty
    }
}
