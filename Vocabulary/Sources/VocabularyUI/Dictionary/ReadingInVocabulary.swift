import Foundation
import VocabularyDomain

/// Whether a dictionary reading is already a saved word, for the page and the search list.
enum ReadingInVocabulary: Equatable {
    case absent
    case saved(Word)

    /// Nil while the saved words are not known, or where there is no way into the
    /// vocabulary.
    init?(_ entry: DictionaryEntry, in words: [Word]?) {
        guard let words else { return nil }
        self = words.first { $0.isReading(of: entry) }.map(Self.saved) ?? .absent
    }

    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }

    /// The saved word, or a new one with the reading's Hanzi, pinyin and first sense.
    func editor(for entry: DictionaryEntry) -> WordEditorTarget {
        switch self {
        case .saved(let word):
            .edit(word)
        case .absent:
            .new(WordDraft(meanings: Array(entry.senses.prefix(1)), hanzi: entry.simplified, pinyin: entry.pinyin))
        }
    }
}
