import Foundation
import VocabularyDomain

/// What the library screens show about decks and folders, shared so they read alike.
extension Vocabulary {
    func canStartLesson(with deck: DeckSummary, minimumMatchingWords: Int) -> Bool {
        usableWordCount(in: deck) >= minimumMatchingWords
    }

    func subtitle(for deck: DeckSummary, minimumMatchingWords: Int) -> String {
        let count = usableWordCount(in: deck)
        return count < minimumMatchingWords ? "\(count) words, needs \(minimumMatchingWords)" : "\(count) words"
    }

    /// Where a deck or folder sits, as a path.
    func location(of folderID: UUID?) -> String {
        guard let folderID else { return "Top level" }
        return path(to: folderID).map(\.displayName).joined(separator: " › ")
    }

    /// Everywhere but where it already is.
    func destinations(forDeck deckID: UUID) -> [MoveDestination] {
        let current = deck(id: deckID)?.folderID
        return destinations { $0 != current && canMoveDeck(deckID, into: $0) }
    }

    /// Everywhere but where it already is.
    func destinations(forFolder folderID: UUID) -> [MoveDestination] {
        let current = folder(id: folderID)?.parentID
        return destinations { $0 != current && canMoveFolder(folderID, into: $0) }
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
