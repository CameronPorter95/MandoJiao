import Foundation

/// How folders nest. The store checks the same rules, so the UI only offers what will work.
/// Siblings are listed in array order, which the store keeps as each one's position.
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

    /// Only into a folder, since every deck lives in one. Its own folder counts, as a reorder.
    func canMoveDeck(_ deckID: UUID, into folderID: UUID?) -> Bool {
        guard deck(id: deckID) != nil, let folderID else { return false }
        return folder(id: folderID) != nil
    }

    /// Never into itself or anything beneath it. Its own parent counts, since that is a reorder.
    func canMoveFolder(_ folderID: UUID, into parentID: UUID?) -> Bool {
        guard folder(id: folderID) != nil else { return false }
        guard let parentID else { return true }
        return self.folder(id: parentID) != nil
            && parentID != folderID
            && !folders(beneath: folderID).contains { $0.id == parentID }
    }

    /// `index` counts the new siblings without the deck itself. Nil puts it last.
    func movingDeck(_ deckID: UUID, into folderID: UUID?, at index: Int?) -> Vocabulary {
        guard canMoveDeck(deckID, into: folderID) else { return self }
        var copy = self
        copy.decks = Self.moving(deckID, in: decks, at: index, parent: \.folderID) { $0.with(folderID: .some(folderID)) }
        return copy
    }

    /// `index` counts the new siblings without the folder itself. Nil puts it last.
    func movingFolder(_ folderID: UUID, into parentID: UUID?, at index: Int?) -> Vocabulary {
        guard canMoveFolder(folderID, into: parentID) else { return self }
        var copy = self
        copy.folders = Self.moving(folderID, in: folders, at: index, parent: \.parentID) { $0.with(parentID: .some(parentID)) }
        return copy
    }

    private static func moving<Item: Identifiable>(
        _ id: Item.ID,
        in items: [Item],
        at index: Int?,
        parent: KeyPath<Item, UUID?>,
        reparent: (Item) -> Item
    ) -> [Item] {
        guard let from = items.firstIndex(where: { $0.id == id }) else { return items }
        var items = items
        let moved = reparent(items.remove(at: from))
        let siblings = items.indices.filter { items[$0][keyPath: parent] == moved[keyPath: parent] }
        if let index, index < siblings.count {
            items.insert(moved, at: siblings[index])
        } else {
            items.insert(moved, at: siblings.last.map { $0 + 1 } ?? items.endIndex)
        }
        return items
    }
}

public nonisolated extension Vocabulary {
    /// Where a deck or folder sits, as a path.
    func location(of folderID: UUID?) -> String {
        guard let folderID else { return "Top level" }
        return path(to: folderID).map(\.displayName).joined(separator: " › ")
    }
}
