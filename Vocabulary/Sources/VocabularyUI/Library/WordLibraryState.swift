import Foundation
import VocabularyDomain

/// The words a search covers, shown in place of the screen searched while the search is
/// open: every word in the library, or, given a folder, every word in the decks beneath it.
struct WordLibraryState: Equatable {
    var folderID: UUID?
    var vocabulary: Vocabulary = .empty {
        didSet { listed = Self.listing(vocabulary, in: folderID, sortedBy: sort) }
    }
    var sort: WordSort = .default {
        didSet { listed = Self.listing(vocabulary, in: folderID, sortedBy: sort) }
    }
    var searchText = ""
    var editor: WordEditorTarget?
    var dictionary: DictionaryHeadword?
    /// Every word listed, sorted, before the search. Kept rather than derived, so typing
    /// only filters: sorting again on every keystroke is what made typing lag. Empty until
    /// `relist()`, since the screen searched builds a new list on every keystroke and only
    /// the first is kept.
    private(set) var listed: [Word] = []

    init(folderID: UUID? = nil, vocabulary: Vocabulary = .empty, sort: WordSort = .default, searchText: String = "") {
        self.folderID = folderID
        self.vocabulary = vocabulary
        self.sort = sort
        self.searchText = searchText
    }

    mutating func relist() {
        listed = Self.listing(vocabulary, in: folderID, sortedBy: sort)
    }

    var folder: FolderSummary? { folderID.flatMap(vocabulary.folder(id:)) }

    /// Before any search.
    var hasWords: Bool {
        guard folderID != nil else { return !vocabulary.words.isEmpty }
        return folder.map { !vocabulary.words(in: $0).isEmpty } ?? false
    }

    /// "565 words", or "12 of 565" while searching.
    var count: String {
        let query = SearchQuery(searchText)
        let all = listed.count == 1 ? "1 word" : "\(listed.count) words"
        return query.isEmpty ? all : "\(words.count) of \(all)"
    }

    /// Sorted, then searched.
    var words: [Word] {
        let query = SearchQuery(searchText)
        return query.isEmpty ? listed : listed.filter { $0.matches(query) }
    }

    private static func listing(_ vocabulary: Vocabulary, in folderID: UUID?, sortedBy sort: WordSort) -> [Word] {
        guard let folderID else { return vocabulary.words(sortedBy: sort) }
        return vocabulary.folder(id: folderID).map { vocabulary.words(in: $0, sortedBy: sort) } ?? []
    }
}

enum WordLibraryAction: Equatable {
    case appeared
    case disappeared
    case searchChanged(String)
    case sortChanged(WordSort)
    case editTapped(UUID)
    case editorDismissed
    case dictionaryTapped(UUID)
    case dictionaryDismissed
    case deleteTapped([UUID])
    case learntToggled(UUID)
}

enum WordLibraryEffect: Equatable, Sendable {
    case showError(VocabularyError)
}
