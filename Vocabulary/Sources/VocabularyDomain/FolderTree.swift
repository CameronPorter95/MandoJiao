import Foundation

/// How folders nest. The store checks the same rules, so the UI only offers what will work.
public nonisolated extension Vocabulary {
    func folder(id: UUID) -> FolderSummary? {
        folders.first { $0.id == id }
    }

    /// The top level when `folderID` is nil.
    func folders(in folderID: UUID?) -> [FolderSummary] {
        folders.filter { $0.parentID == folderID }
    }

    /// The top level when `folderID` is nil.
    func decks(in folderID: UUID?) -> [DeckSummary] {
        decks.filter { $0.folderID == folderID }
    }

    /// Depth first, each after its parent.
    func folders(beneath folderID: UUID) -> [FolderSummary] {
        var result: [FolderSummary] = []
        var visited: Set<UUID> = [folderID]
        func visit(_ id: UUID) {
            for child in folders(in: id) where visited.insert(child.id).inserted {
                result.append(child)
                visit(child.id)
            }
        }
        visit(folderID)
        return result
    }

    func decks(beneath folderID: UUID) -> [DeckSummary] {
        ([folderID] + folders(beneath: folderID).map(\.id)).flatMap { decks(in: $0) }
    }

    /// Every word in every deck beneath, once each.
    func words(in folder: FolderSummary) -> [Word] {
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        return decks(beneath: folder.id)
            .flatMap(\.wordIDs)
            .filter { seen.insert($0).inserted }
            .compactMap { byID[$0] }
    }

    func usableWordCount(in folder: FolderSummary) -> Int {
        words(in: folder).filter(\.isUsable).count
    }

    /// From the top-level folder down to this one.
    func path(to folderID: UUID) -> [FolderSummary] {
        var path: [FolderSummary] = []
        var next = folder(id: folderID)
        while let current = next, !path.contains(where: { $0.id == current.id }) {
            path.insert(current, at: 0)
            next = current.parentID.flatMap(folder(id:))
        }
        return path
    }

    func canMoveDeck(_ deckID: UUID, into folderID: UUID?) -> Bool {
        guard let deck = deck(id: deckID), deck.folderID != folderID else { return false }
        return folderID.map { folder(id: $0) != nil } ?? true
    }

    /// Never into itself or anything beneath it.
    func canMoveFolder(_ folderID: UUID, into parentID: UUID?) -> Bool {
        guard let folder = folder(id: folderID), folder.parentID != parentID else { return false }
        guard let parentID else { return true }
        return self.folder(id: parentID) != nil
            && parentID != folderID
            && !folders(beneath: folderID).contains { $0.id == parentID }
    }
}
