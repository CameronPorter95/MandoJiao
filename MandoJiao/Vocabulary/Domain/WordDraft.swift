import Foundation

/// A word as typed, before it is saved.
nonisolated struct WordDraft: Equatable, Sendable {
    var english = ""
    var hanzi = ""
    var pinyin = ""

    var trimmed: WordDraft {
        WordDraft(
            english: english.trimmingCharacters(in: .whitespacesAndNewlines),
            hanzi: hanzi.trimmingCharacters(in: .whitespacesAndNewlines),
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// English and Hanzi are required; pinyin is optional.
    var isComplete: Bool {
        let trimmed = trimmed
        return !trimmed.english.isEmpty && !trimmed.hanzi.isEmpty
    }
}
