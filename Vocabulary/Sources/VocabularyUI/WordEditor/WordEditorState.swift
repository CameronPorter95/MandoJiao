import Foundation
import VocabularyDomain

struct WordEditorState: Equatable {
    /// Nil for a new word.
    let wordID: UUID?
    var draft: WordDraft

    var title: String { wordID == nil ? "New word" : "Edit word" }
    var canSave: Bool { draft.isComplete }
    var canDelete: Bool { wordID != nil }
}

enum WordEditorAction: Equatable {
    case englishChanged(String)
    case hanziChanged(String)
    case pinyinChanged(String)
    case saveTapped
    case deleteTapped
    case cancelTapped
}

enum WordEditorEffect: Equatable, Sendable {
    case dismiss
    case showError(VocabularyError)
}
