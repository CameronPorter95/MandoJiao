import Foundation
import VocabularyDomain

/// What the library's sidebar has open.
public enum LibrarySelection: Hashable, Sendable {
    case allWords
    case folder(UUID)
}

/// A screen pushed over the selection: a folder opened from inside another, or a deck.
public enum LibraryPage: Hashable, Sendable {
    case folder(UUID)
    case deck(UUID)
}

/// How a screen the library shows asks it to push another.
@MainActor
public struct LibraryColumnNavigation {
    public let openDeck: (UUID) -> Void
    public let openFolder: (UUID) -> Void
    public let expansion: FolderExpansion
}

/// Which folders are unfolded, shared by the tree and every folder screen so each shows a
/// folder the way it was last left.
@MainActor
public struct FolderExpansion {
    public let expanded: Set<UUID>
    /// Folders whose screen has its Folders section folded away.
    public let foldedSections: Set<UUID>
    public let setExpanded: (UUID, Bool) -> Void
    public let toggleSection: (UUID) -> Void
}

/// A folder about to be named: a new one, or an existing one being renamed.
enum FolderNaming: Equatable {
    case new(parentID: UUID?)
    case rename(UUID)
}

struct LibraryState: Equatable {
    var vocabulary: Vocabulary = .empty
    var selection: LibrarySelection?
    /// Pushed over the selection, in order.
    var path: [LibraryPage] = []
    /// Folded unless listed, everywhere a folder appears in a tree.
    var expandedFolders: Set<UUID> = []
    var foldedSections: Set<UUID> = []
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
    case opened(LibraryPage)
    /// The stack after going back.
    case pathChanged([LibraryPage])
    case folderExpanded(UUID, Bool)
    case folderSectionToggled(UUID)
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
