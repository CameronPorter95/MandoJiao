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

struct WordLibraryState: Equatable {
    var vocabulary: Vocabulary = .empty
    var searchText = ""
    var editor: WordEditorTarget?
    var dictionary: DictionaryHeadword?

    var words: [Word] { vocabulary.words.sorted { $0.english < $1.english } }
    var filteredWords: [Word] { words.filter { $0.matches(searchText) } }
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
