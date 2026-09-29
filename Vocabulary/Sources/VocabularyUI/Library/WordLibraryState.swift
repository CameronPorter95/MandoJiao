import Foundation
import VocabularyDomain

/// Which word the editor sheet is open on.
enum WordEditorTarget: Identifiable, Equatable {
    case new
    case edit(Word)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let word): word.id.uuidString
        }
    }

    var word: Word? {
        if case .edit(let word) = self { return word }
        return nil
    }
}

/// Every word in the library, or, given a folder, every word in the decks beneath it.
struct WordLibraryState: Equatable {
    var folderID: UUID?
    var vocabulary: Vocabulary = .empty
    var searchText = ""
    var editor: WordEditorTarget?
    var dictionary: DictionaryHeadword?

    var folder: FolderSummary? { folderID.flatMap(vocabulary.folder(id:)) }

    /// Before any search.
    var hasWords: Bool {
        guard folderID != nil else { return !vocabulary.words.isEmpty }
        return folder.map { !vocabulary.words(in: $0).isEmpty } ?? false
    }

    func words(sortedBy sort: WordSort) -> [Word] {
        let words = if folderID != nil {
            folder.map { vocabulary.words(in: $0, sortedBy: sort) } ?? []
        } else {
            vocabulary.words(sortedBy: sort)
        }
        return words.filter { $0.matches(searchText) }
    }
}

enum WordLibraryAction: Equatable {
    case appeared
    case disappeared
    case searchChanged(String)
    case addTapped
    case editTapped(UUID)
    case editorDismissed
    case dictionaryTapped(UUID)
    case dictionaryDismissed
    case deleteTapped([UUID])
}

enum WordLibraryEffect: Equatable, Sendable {
    case showError(VocabularyError)
}
