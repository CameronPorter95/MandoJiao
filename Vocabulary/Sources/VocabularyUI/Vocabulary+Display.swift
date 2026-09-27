import Foundation
import VocabularyDomain

/// What the deck and folder screens show about the library, shared so they read alike.
extension Vocabulary {
    func canStartLesson(with deck: DeckSummary, minimumMatchingWords: Int) -> Bool {
        usableWordCount(in: deck) >= minimumMatchingWords
    }

    func canStartLesson(with folder: FolderSummary, minimumMatchingWords: Int) -> Bool {
        usableWordCount(in: folder) >= minimumMatchingWords
    }

    func subtitle(for deck: DeckSummary, minimumMatchingWords: Int) -> String {
        let count = usableWordCount(in: deck)
        return count < minimumMatchingWords ? "\(count) words, needs \(minimumMatchingWords)" : "\(count) words"
    }

    func subtitle(for folder: FolderSummary, minimumMatchingWords: Int) -> String {
        let contents = [
            Self.counted(folders(in: folder.id).count, "folder"),
            Self.counted(decks(in: folder.id).count, "deck"),
        ].compactMap { $0 }
        guard !contents.isEmpty else { return "Empty" }
        return (contents + ["\(usableWordCount(in: folder)) words"]).joined(separator: ", ")
    }

    /// Where a deck or folder sits, as a path.
    func location(of folderID: UUID?) -> String {
        guard let folderID else { return "Top level" }
        return path(to: folderID).map(\.displayName).joined(separator: " › ")
    }

    func destinations(forDeck deckID: UUID) -> [MoveDestination] {
        destinations { canMoveDeck(deckID, into: $0) }
    }

    func destinations(forFolder folderID: UUID) -> [MoveDestination] {
        destinations { canMoveFolder(folderID, into: $0) }
    }

    /// Nil when the folder can go without asking, because it is empty.
    func deletionWarning(forFolder folderID: UUID) -> String? {
        guard let folder = folder(id: folderID) else { return nil }
        let contents = [
            Self.counted(folders(beneath: folderID).count, "folder"),
            Self.counted(decks(beneath: folderID).count, "deck"),
        ].compactMap { $0 }
        guard !contents.isEmpty else { return nil }
        return "\(folder.displayName) and the \(contents.joined(separator: " and ")) inside it will be deleted. Their words stay in the library."
    }

    /// The folder and everything beneath it gone, for an optimistic delete.
    func removingFolder(_ folderID: UUID) -> Vocabulary {
        let doomed = Set([folderID] + folders(beneath: folderID).map(\.id))
        var copy = self
        copy.folders.removeAll { doomed.contains($0.id) }
        copy.decks.removeAll { $0.folderID.map(doomed.contains) ?? false }
        return copy
    }

    private func destinations(where canMove: (UUID?) -> Bool) -> [MoveDestination] {
        let top = canMove(nil) ? [MoveDestination(folderID: nil, title: "Top level")] : []
        let folders = folders
            .filter { canMove($0.id) }
            .map { MoveDestination(folderID: $0.id, title: location(of: $0.id)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return top + folders
    }

    private static func counted(_ count: Int, _ noun: String) -> String? {
        switch count {
        case 0: nil
        case 1: "1 \(noun)"
        default: "\(count) \(noun)s"
        }
    }
}
