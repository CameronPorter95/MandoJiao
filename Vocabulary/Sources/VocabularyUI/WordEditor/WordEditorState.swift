import Foundation
import VocabularyDomain

struct WordEditorState: Equatable {
    /// Nil for a new word.
    let wordID: UUID?
    var draft: WordDraft
    /// May be for Hanzi that has since changed, so read it through the fields below.
    var suggestion: WordSuggestion?

    var title: String { wordID == nil ? "New word" : "Edit word" }
    var canSave: Bool { submission.isComplete }
    var canDelete: Bool { wordID != nil }

    /// Shown in place of an empty pinyin field, and saved unless typed over.
    var pinyinSuggestion: String? { suggested(\.pinyin, over: draft.pinyin) }
    var englishSuggestion: String? { suggested(\.english, over: draft.english) }

    var submission: WordDraft {
        var submission = draft
        if let pinyinSuggestion { submission.pinyin = pinyinSuggestion }
        if let englishSuggestion { submission.english = englishSuggestion }
        return submission
    }

    private func suggested(_ field: KeyPath<WordSuggestion, String>, over typed: String) -> String? {
        guard typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let suggestion, suggestion.hanzi == draft.trimmed.hanzi,
              !suggestion[keyPath: field].isEmpty
        else { return nil }
        return suggestion[keyPath: field]
    }
}

enum WordEditorAction: Equatable {
    case appeared
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
