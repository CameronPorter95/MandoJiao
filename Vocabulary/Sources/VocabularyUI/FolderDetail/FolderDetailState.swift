import Foundation
import VocabularyDomain

struct FolderDetailState: Equatable {
    let folderID: UUID
    let minimumMatchingWords: Int
    var vocabulary: Vocabulary = .empty
    /// Nil until the folder first loads, then whatever has been typed.
    var name: String?
    /// What the naming alert will create, while it is up.
    var naming: NewItemKind?
    var newItemName = ""
    var isChoosingDestination = false
    /// A folder inside with something in it, waiting on confirmation before it goes.
    var pendingFolderDeletion: UUID?

    var folder: FolderSummary? { vocabulary.folder(id: folderID) }
    var title: String { (name ?? "").isEmpty ? "Folder" : name ?? "" }

    var folders: [FolderSummary] { vocabulary.folders(in: folderID) }
    var decks: [DeckSummary] { vocabulary.decks(in: folderID) }
    var isEmpty: Bool { folders.isEmpty && decks.isEmpty }

    var wordCount: Int { folder.map(vocabulary.usableWordCount(in:)) ?? 0 }
    var canStartLesson: Bool { wordCount >= minimumMatchingWords }

    var location: String { vocabulary.location(of: folder?.parentID) }
    var destinations: [MoveDestination] { vocabulary.destinations(forFolder: folderID) }
    /// Shown when there is nowhere to move to, so the row does not look broken.
    var moveUnavailableReason: String? {
        destinations.isEmpty ? "Make another folder first to move this one into." : nil
    }

    var deletionWarning: String? { pendingFolderDeletion.flatMap(vocabulary.deletionWarning(forFolder:)) }
}

enum FolderDetailAction: Equatable {
    case appeared
    case disappeared
    case nameChanged(String)
    case startLessonTapped
    case newItemTapped(NewItemKind)
    case newItemNameChanged(String)
    case createConfirmed
    case createCancelled
    case practiseFolderTapped(UUID)
    case practiseDeckTapped(UUID)
    case deleteFolderTapped(UUID)
    case deleteFolderConfirmed
    case deleteFolderCancelled
    case deleteDeckTapped(UUID)
    case moveTapped
    case destinationChosen(UUID?)
    case moveCancelled
}

enum FolderDetailEffect: Equatable, Sendable {
    case startLesson(LessonRequest)
    case showError(VocabularyError)
}
