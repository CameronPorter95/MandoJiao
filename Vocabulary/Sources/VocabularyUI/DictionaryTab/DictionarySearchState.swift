import Foundation
import VocabularyDomain

struct DictionarySearchState: Equatable {
    enum Results: Equatable {
        case none
        case searching
        case found([DictionarySearchResult])
        case failed
    }

    var query = ""
    var results: Results = .none

    var isBlank: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum DictionarySearchAction: Equatable {
    case queryChanged(String)
}
