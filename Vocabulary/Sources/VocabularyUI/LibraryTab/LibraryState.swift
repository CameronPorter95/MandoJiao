import Foundation
import VocabularyDomain

/// What the library's sidebar has open.
public enum LibrarySelection: Hashable, Sendable {
    case allWords
    case topLevelDecks
    case folder(UUID)
}

/// A folder about to be named: a new one, or an existing one being renamed.
enum FolderNaming: Equatable {
    case new(parentID: UUID?)
    case rename(UUID)
}

struct LibraryState: Equatable {
    var vocabulary: Vocabulary = .empty
    var selection: LibrarySelection?
    /// The deck shown in the last column, or pushed on iPhone.
    var openDeck: UUID?
    var isEditing = false
    var naming: FolderNaming?
    var name = ""
    /// A folder with something inside, waiting on confirmation before it goes.
    var pendingFolderDeletion: UUID?

    var deletionWarning: String? { pendingFolderDeletion.flatMap(vocabulary.deletionWarning(forFolder:)) }

    var namingTitle: String {
        switch naming {
        case .rename: "Rename folder"
        default: "New folder"
        }
    }

    var namingMessage: String {
        switch naming {
        case .new(let parentID?): "It goes inside \(vocabulary.folder(id: parentID)?.displayName ?? "the folder")."
        case .new(nil): "Give the folder a name, then add decks or folders to it."
        case .rename, nil: ""
        }
    }
}

enum LibraryAction: Equatable {
    case appeared
    case disappeared
    /// Nil when going back to the sidebar on iPhone.
    case selected(LibrarySelection?)
    /// Nil when going back from the deck on iPhone.
    case deckOpened(UUID?)
    case editTapped
    case folderMoved(id: UUID, parentID: UUID?, index: Int)
    case newFolderTapped(parentID: UUID?)
    case renameFolderTapped(UUID)
    case nameChanged(String)
    case namingConfirmed
    case namingCancelled
    case practiseFolderTapped(UUID)
    case deleteFolderTapped(UUID)
    case deleteFolderConfirmed
    case deleteFolderCancelled
}

enum LibraryEffect: Equatable, Sendable {
    case requestMatching(LessonRequest)
    case showError(VocabularyError)
}
