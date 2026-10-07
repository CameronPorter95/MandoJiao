import DictionaryDomain
import Foundation
import VocabularyDomain

/// What the editor sheet opens on: a new word, blank or filled in from the dictionary, or
/// one already saved.
public enum WordEditorTarget: Identifiable, Equatable, Sendable {
    case new(WordDraft)
    case edit(Word)
    /// A saved word known only by its id, as the dictionary knows it. Read from the store
    /// when the editor appears.
    case saved(UUID)

    public var id: String {
        switch self {
        case .new: "new"
        case .edit(let word): word.id.uuidString
        case .saved(let id): id.uuidString
        }
    }

    /// A reading not saved becomes a new word with its Hanzi, pinyin and first sense.
    public init(_ edit: ReadingEdit) {
        switch edit {
        case .add(let entry):
            self = .new(WordDraft(meanings: Array(entry.senses.prefix(1)), hanzi: entry.simplified, pinyin: entry.pinyin))
        case .open(let saved):
            self = .saved(saved.id)
        }
    }
}
