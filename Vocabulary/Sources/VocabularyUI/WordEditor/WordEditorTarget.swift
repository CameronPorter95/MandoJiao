import Foundation
import VocabularyDomain

/// What the editor sheet opens on: a new word, blank or filled in from the dictionary, or
/// one already saved.
public enum WordEditorTarget: Identifiable, Equatable, Sendable {
    case new(WordDraft)
    case edit(Word)

    public var id: String {
        switch self {
        case .new: "new"
        case .edit(let word): word.id.uuidString
        }
    }
}
