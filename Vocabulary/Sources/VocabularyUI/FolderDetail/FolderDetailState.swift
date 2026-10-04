import Foundation
import VocabularyDomain

/// One folder: the folders beneath it, then its own decks. The folders are shown to open,
/// not to rearrange; that happens in the library's tree, as in Notes.
struct FolderDetailState: Equatable {
    let folderID: UUID
    let minimumMatchingWords: Int
    var vocabulary: Vocabulary = .empty
    /// What the naming alert is for, while it is up.
    var naming: Naming?
    var newName = ""
    /// A subfolder with something inside, waiting on confirmation before it goes.
    var pendingFolderDeletion: UUID?
    /// While open, the folder's words show in place of its folders and decks.
    var isSearching = false
    var searchText = ""

    enum Naming: Equatable {
        case newDeck
        /// Inside this folder, as a subfolder.
        case newFolder
        /// This folder.
        case rename
    }

    /// A folder beneath this one, with everything beneath it in turn.
    struct Subfolder: Identifiable, Equatable {
        let folder: FolderSummary
        let deckCount: Int
        let children: [Subfolder]?
        var id: UUID { folder.id }
    }

    var folder: FolderSummary? { vocabulary.folder(id: folderID) }
    var title: String { folder?.displayName ?? "Folder" }
    var decks: [DeckSummary] { vocabulary.decks(in: folderID) }

    func decks(sortedBy sort: DeckSort) -> [DeckSummary] {
        vocabulary.decks(in: folderID, sortedBy: sort)
    }
    var subfolders: [Subfolder] { subfolders(in: folderID) }

    /// "2 decks · 3 folders", counting every folder beneath, as Notes does.
    var summary: String {
        let decks = decks.count
        let folders = vocabulary.folders(beneath: folderID).count
        let parts = [
            decks == 1 ? "1 deck" : "\(decks) decks",
            folders == 0 ? nil : folders == 1 ? "1 folder" : "\(folders) folders",
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    var deletionWarning: String? { pendingFolderDeletion.flatMap(vocabulary.deletionWarning(forFolder:)) }

    /// Only offered where a lesson would start, for a folder or deck in this one.
    func canPractise(folder id: UUID) -> Bool {
        vocabulary.folder(id: id).map { vocabulary.canStartLesson(with: $0, minimumMatchingWords: minimumMatchingWords) } ?? false
    }

    func canPractise(_ deck: DeckSummary) -> Bool {
        vocabulary.canStartLesson(with: deck, minimumMatchingWords: minimumMatchingWords)
    }

    var wordCount: Int { folder.map(vocabulary.usableWordCount(in:)) ?? 0 }
    var canStartLesson: Bool { wordCount >= minimumMatchingWords }

    private func subfolders(in parentID: UUID) -> [Subfolder] {
        vocabulary.folders(in: parentID).map { folder in
            let children = subfolders(in: folder.id)
            return Subfolder(
                folder: folder,
                deckCount: vocabulary.decks(beneath: folder.id).count,
                children: children.isEmpty ? nil : children
            )
        }
    }
}

enum FolderDetailAction: Equatable {
    case appeared
    case disappeared
    case startLessonTapped
    case searchPresentedChanged(Bool)
    case searchChanged(String)
    case namingTapped(FolderDetailState.Naming)
    case newNameChanged(String)
    case namingConfirmed
    case namingCancelled
    case practiseFolderTapped(UUID)
    case practiseDeckTapped(UUID)
    case deleteDeckTapped(UUID)
    case deleteFolderTapped(UUID)
    case deleteFolderConfirmed
    case deleteFolderCancelled
}

enum FolderDetailEffect: Equatable, Sendable {
    case startLesson(LessonRequest)
    case showError(VocabularyError)
}
