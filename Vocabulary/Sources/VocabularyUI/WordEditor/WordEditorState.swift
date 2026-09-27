import Foundation
import VocabularyDomain

struct WordEditorState: Equatable {
    /// What the lexicon and the dictionary know about some Hanzi, which may since have
    /// changed, so read it through the properties below.
    struct Lookup: Equatable {
        let hanzi: String
        let suggestion: WordSuggestion?
        /// The preferred reading first.
        let entries: [DictionaryEntry]
    }

    /// Nil for a new word.
    let wordID: UUID?
    var draft: WordDraft
    var lookup: Lookup?
    /// Until the meanings are touched, a new word takes the dictionary's first sense for
    /// whatever Hanzi is typed. After that they are the user's, whatever the Hanzi.
    var meaningsEdited: Bool

    init(wordID: UUID?, draft: WordDraft, lookup: Lookup? = nil) {
        self.wordID = wordID
        self.draft = draft
        self.lookup = lookup
        self.meaningsEdited = !draft.meanings.isEmpty
    }

    var title: String { wordID == nil ? "New word" : "Edit word" }
    var canSave: Bool { submission.isComplete }
    var canDelete: Bool { wordID != nil }

    /// Every reading of the Hanzi as typed, empty while it is being looked up.
    var entries: [DictionaryEntry] {
        guard let lookup, lookup.hanzi == draft.trimmed.hanzi else { return [] }
        return lookup.entries
    }

    /// In order, the headline first, as saved.
    var meanings: [String] { meaningsEdited ? draft.meanings : suggestedMeanings }

    /// Shown tinted, since they are saved unless changed.
    var meaningsAreSuggested: Bool { !meaningsEdited && !suggestedMeanings.isEmpty }

    private var suggestedMeanings: [String] {
        entries.first?.senses.first.map { [$0] } ?? []
    }

    /// Shown in place of an empty pinyin field, and saved unless typed over. The reading
    /// the headline comes from, so ticking a sense of 行 háng suggests háng.
    var pinyinSuggestion: String? {
        guard draft.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let headline = meanings.first, let entry = entries.first(where: { $0.senses.contains(headline) }) {
            return entry.pinyin
        }
        guard let lookup, lookup.hanzi == draft.trimmed.hanzi,
              let pinyin = lookup.suggestion?.pinyin, !pinyin.isEmpty
        else { return nil }
        return pinyin
    }

    var submission: WordDraft {
        var submission = draft
        submission.meanings = meanings
        if let pinyinSuggestion { submission.pinyin = pinyinSuggestion }
        return submission
    }

    /// Meanings not among the dictionary's senses for this Hanzi, which only the list shows.
    func isCustom(_ meaning: String) -> Bool {
        !entries.contains { $0.senses.contains(meaning) }
    }

    func isChosen(_ sense: String) -> Bool { meanings.contains(sense) }

    mutating func editMeanings(_ change: (inout [String]) -> Void) {
        var edited = meanings
        change(&edited)
        draft.meanings = edited
        meaningsEdited = true
    }
}

enum WordEditorAction: Equatable {
    case appeared
    case hanziChanged(String)
    case pinyinChanged(String)
    case senseToggled(String)
    case meaningAdded(String)
    case meaningsMoved(from: IndexSet, to: Int)
    case meaningsRemoved(IndexSet)
    case meaningMadeHeadline(String)
    case saveTapped
    case deleteTapped
    case cancelTapped
}

enum WordEditorEffect: Equatable, Sendable {
    case dismiss
    case showError(VocabularyError)
}
