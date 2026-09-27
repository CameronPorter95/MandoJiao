import Foundation
import VocabularyDomain

/// The decks in one folder, or at the top level when `folderID` is nil. Subfolders are in
/// the library's tree, as in Notes.
struct FolderDetailState: Equatable {
    let folderID: UUID?
    let minimumMatchingWords: Int
    var vocabulary: Vocabulary = .empty
    var isNamingDeck = false
    var newDeckName = ""

    var folder: FolderSummary? { folderID.flatMap(vocabulary.folder(id:)) }
    var title: String { folderID == nil ? "Decks" : folder?.displayName ?? "Folder" }
    var decks: [DeckSummary] { vocabulary.decks(in: folderID) }

    /// Only a real folder is practised as a whole. The top level has quick practice on home.
    var practisesAsWhole: Bool { folder != nil }
    var wordCount: Int { folder.map(vocabulary.usableWordCount(in:)) ?? 0 }
    var canStartLesson: Bool { wordCount >= minimumMatchingWords }
}

enum FolderDetailAction: Equatable {
    case appeared
    case disappeared
    case startLessonTapped
    case newDeckTapped
    case newDeckNameChanged(String)
    case createDeckConfirmed
    case createDeckCancelled
    case practiseDeckTapped(UUID)
    case deleteDeckTapped(UUID)
    case decksMoved(from: IndexSet, to: Int)
}

enum FolderDetailEffect: Equatable, Sendable {
    case startLesson(LessonRequest)
    case showError(VocabularyError)
}
