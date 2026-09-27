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
    /// The unfolded subfolders on one folder's screen, which are its own.
    public let expansion: (UUID) -> FolderExpansion
}

/// One folder screen's share of the library's layout: which of its subfolders are unfolded,
/// and whether its Folders section is.
@MainActor
public struct FolderExpansion {
    public let expanded: Set<UUID>
    public let isSectionFolded: Bool
    public let setExpanded: (UUID, Bool) -> Void
    public let toggleSection: () -> Void
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
    /// Saved after every change, so it is as it was left after a relaunch.
    var layout = LibraryLayout()
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
    case folderExpanded(UUID, Bool, in: LibraryLayout.Scope)
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
