import Foundation
import VocabularyDomain

/// What the library's sidebar has open. Words are found by searching, not opened.
public enum LibrarySelection: Hashable, Sendable {
    case folder(UUID)
}

/// A screen pushed over the selection: a folder opened from inside another, or a deck.
public enum LibraryPage: Hashable, Sendable {
    case folder(UUID)
    case deck(UUID)
}

/// What a screen the library pushes starts from, and how it asks to push another.
@MainActor
public struct LibraryPageContext {
    /// The library's latest snapshot, so a pushed screen shows its name before its own
    /// subscription delivers.
    public let vocabulary: Vocabulary
    public let openDeck: (UUID) -> Void
    public let openFolder: (UUID) -> Void
    /// One folder's screen's share of the layout, which is its own.
    public let layout: (UUID) -> FolderLayout
    /// The search results' share of it, the library's and every folder's alike.
    public let wordList: WordListLayout
}

/// How a search's results are sorted. The library owns the saved layout, so the list asks
/// it to change rather than saving its own copy, which the library's next save would undo.
@MainActor
public struct WordListLayout {
    public let sort: WordSort
    public let setSort: (WordSort) -> Void

    public init(sort: WordSort, setSort: @escaping (WordSort) -> Void) {
        self.sort = sort
        self.setSort = setSort
    }
}

/// How one folder's screen was last left: its unfolded subfolders, its folded sections, and
/// how it sorts its decks.
@MainActor
public struct FolderLayout {
    public let expanded: Set<UUID>
    public let foldedSections: Set<LibraryLayout.Section>
    public let deckSort: DeckSort
    public let setExpanded: (UUID, Bool) -> Void
    public let toggle: (LibraryLayout.Section) -> Void
    public let setDeckSort: (DeckSort) -> Void
}

/// A folder about to be named: a new one, or an existing one being renamed.
enum FolderNaming: Equatable {
    case new(parentID: UUID?)
    case rename(UUID)
}

struct LibraryState: Equatable {
    /// The matching lesson's floor, which a folder must reach to be practised.
    let minimumMatchingWords: Int
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
    var isShowingHSKLevels = false
    /// While open, every word in the library shows in place of the tree, filtered as typed.
    var isSearching = false
    var searchText = ""
    /// A new word, since the library has no list of words to add one from.
    var editor: WordEditorTarget?

    var deletionWarning: String? { pendingFolderDeletion.flatMap(vocabulary.deletionWarning(forFolder:)) }

    func canPractise(_ folderID: UUID) -> Bool {
        vocabulary.folder(id: folderID).map {
            vocabulary.canStartLesson(with: $0, minimumMatchingWords: minimumMatchingWords)
        } ?? false
    }

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
    case folderSectionToggled(UUID, LibraryLayout.Section)
    case deckSortChanged(UUID, DeckSort)
    case wordSortChanged(WordSort)
    case hskLevelsTapped
    case hskLevelsDismissed
    case searchPresentedChanged(Bool)
    case searchChanged(String)
    case newWordTapped
    case editorDismissed
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
