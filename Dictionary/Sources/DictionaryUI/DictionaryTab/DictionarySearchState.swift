import DictionaryDomain
import Foundation

struct DictionarySearchState: Equatable {
    enum Results: Equatable {
        case none
        case found([DictionarySearchResult])
        case failed
    }

    var query = ""
    var results: Results = .none
    /// A search for `query` under way. `results` still holds the last one's meanwhile, so the
    /// list does not blank between keystrokes.
    var isSearching = false
    /// The saved words, nil until they are known.
    var saved: [SavedReading]?
    var editor: ReadingEdit?
    /// Headword pages pushed over the search, in order: a result's, then its characters'.
    var path: [DictionaryHeadword] = []

    var isBlank: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var hasResults: Bool {
        if case .found(let found) = results { !found.isEmpty } else { false }
    }

    func vocabulary(for result: DictionarySearchResult) -> ReadingInVocabulary? {
        ReadingInVocabulary(result.entry, in: saved)
    }
}

enum DictionarySearchAction: Equatable {
    case appeared
    case disappeared
    case queryChanged(String)
    /// Adds the result's reading, or opens it where it is already saved.
    case vocabularyTapped(DictionarySearchResult)
    case editorDismissed
    /// A result's page, or a character's from a page, pushed onto the stack.
    case opened(DictionaryHeadword)
    /// The stack after going back.
    case pathChanged([DictionaryHeadword])
}
