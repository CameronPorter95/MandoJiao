import Foundation

/// A word as typed, before it is saved.
public nonisolated struct WordDraft: Equatable, Sendable {
    /// The first is the headline.
    public var meanings: [String] = []
    public var hanzi = ""
    public var pinyin = ""

    public init(meanings: [String], hanzi: String = "", pinyin: String = "") {
        self.meanings = meanings
        self.hanzi = hanzi
        self.pinyin = pinyin
    }

    /// One meaning, or none when `english` is empty.
    public init(english: String = "", hanzi: String = "", pinyin: String = "") {
        self.init(meanings: english.isEmpty ? [] : [english], hanzi: hanzi, pinyin: pinyin)
    }

    /// The headline. Setting it replaces the headline and keeps the other meanings.
    public var english: String {
        get { meanings.first ?? "" }
        set {
            let others = meanings.dropFirst()
            meanings = (newValue.isEmpty ? [] : [newValue]) + others
        }
    }

    /// Every field trimmed, and blank or repeated meanings dropped, keeping the first of each.
    public var trimmed: WordDraft {
        var seen = Set<String>()
        let meanings = self.meanings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        return WordDraft(
            meanings: meanings,
            hanzi: hanzi.trimmingCharacters(in: .whitespacesAndNewlines),
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// A meaning and Hanzi are required; pinyin is optional.
    public var isComplete: Bool {
        let trimmed = trimmed
        return !trimmed.meanings.isEmpty && !trimmed.hanzi.isEmpty
    }
}
