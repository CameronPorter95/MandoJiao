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

    /// A deck a new word can join, titled by where it sits.
    struct DeckChoice: Identifiable, Equatable {
        let id: UUID
        let title: String
    }

    /// Nil for a new word.
    let wordID: UUID?
    var draft: WordDraft
    var lookup: Lookup?
    /// Until the meanings are touched, a new word takes the dictionary's first sense for
    /// whatever Hanzi is typed. After that they are the user's, whatever the Hanzi.
    var meaningsEdited: Bool
    var dictionary: DictionaryHeadword?
    var isChoosingSenses = false
    /// For the decks a new word can join. Empty until first heard, and never heard for a
    /// saved word.
    var vocabulary: Vocabulary = .empty
    /// Kept while its deck is gone, but only saved into while it exists.
    var deckID: UUID?

    init(wordID: UUID?, draft: WordDraft, lookup: Lookup? = nil) {
        self.wordID = wordID
        self.draft = draft
        self.lookup = lookup
        self.meaningsEdited = !draft.meanings.isEmpty
    }

    var title: String { wordID == nil ? "New word" : "Edit word" }
    var canSave: Bool { submission.isComplete }
    var canDelete: Bool { wordID != nil }

    /// Only a new word joins a deck here. A saved one's decks are changed from each deck.
    var deckChoices: [DeckChoice] {
        guard wordID == nil else { return [] }
        return vocabulary.decks
            .map { deck in
                let title = deck.folderID == nil
                    ? deck.displayName
                    : "\(vocabulary.location(of: deck.folderID)) › \(deck.displayName)"
                return DeckChoice(id: deck.id, title: title)
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The deck the word will join, nil if none was chosen or it has since been deleted.
    var chosenDeckID: UUID? {
        guard wordID == nil else { return nil }
        return deckID.flatMap { vocabulary.deck(id: $0)?.id }
    }

    /// Every reading of the Hanzi as typed, empty while it is being looked up.
    var entries: [DictionaryEntry] {
        guard let lookup, lookup.hanzi == draft.trimmed.hanzi else { return [] }
        return lookup.entries
    }

    /// Readings with senses to tick. Some have none, like a bare surname or a character only
    /// used in one word.
    var tickableEntries: [DictionaryEntry] { entries.filter { !$0.senses.isEmpty } }

    /// The Hanzi, with the reading that would be saved.
    var dictionaryHeadword: DictionaryHeadword? {
        let hanzi = draft.trimmed.hanzi
        guard !hanzi.isEmpty else { return nil }
        let pinyin = submission.trimmed.pinyin
        return DictionaryHeadword(hanzi: hanzi, pinyin: pinyin.isEmpty ? nil : pinyin)
    }

    /// In order, the headline first, as saved.
    var meanings: [String] { meaningsEdited ? draft.meanings : suggestedMeanings }

    /// One row even with no meanings, the field the headline is typed into.
    var meaningRows: [String] { meanings.isEmpty ? [""] : meanings }

    /// Only once there is a headline, so a new word starts with one field.
    var canAddMeaning: Bool {
        !(meanings.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Shown tinted, since they are saved unless changed.
    var meaningsAreSuggested: Bool { !meaningsEdited && !suggestedMeanings.isEmpty }

    private var suggestedMeanings: [String] {
        tickableEntries.first?.senses.first.map { [$0] } ?? []
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
    case disappeared
    case hanziChanged(String)
    case pinyinChanged(String)
    case senseToggled(String)
    case meaningAdded(String)
    case meaningEdited(at: Int, text: String)
    case meaningsMoved(from: IndexSet, to: Int)
    case meaningsRemoved(IndexSet)
    case sensesTapped
    case sensesDismissed
    case dictionaryTapped
    case dictionaryDismissed
    case deckChosen(UUID?)
    case saveTapped
    case deleteTapped
    case cancelTapped
}

enum WordEditorEffect: Equatable, Sendable {
    case dismiss
    case showError(VocabularyError)
}
