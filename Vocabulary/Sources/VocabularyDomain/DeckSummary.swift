import Foundation

/// A named subset of the library, by word identity.
public nonisolated struct DeckSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let wordIDs: [UUID]
    /// Every deck the app makes has one. Optional only so a store that lacks it still opens.
    public let folderID: UUID?
    /// Identifies a deck the app supplies, such as part of an HSK level, however it is renamed.
    public let builtInKey: String?

    public init(
        id: UUID,
        name: String,
        createdAt: Date,
        wordIDs: [UUID],
        folderID: UUID? = nil,
        builtInKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.wordIDs = wordIDs
        self.folderID = folderID
        self.builtInKey = builtInKey
    }

    public var displayName: String { name.isEmpty ? "Untitled deck" : name }
}

public nonisolated extension DeckSummary {
    func settingMembership(of wordID: UUID, to isIncluded: Bool) -> DeckSummary {
        var wordIDs = self.wordIDs.filter { $0 != wordID }
        if isIncluded { wordIDs.append(wordID) }
        return with(wordIDs: wordIDs)
    }

    /// `folderID: .some(nil)` moves the deck to the top level.
    func with(name: String? = nil, wordIDs: [UUID]? = nil, folderID: UUID?? = nil) -> DeckSummary {
        DeckSummary(
            id: id,
            name: name ?? self.name,
            createdAt: createdAt,
            wordIDs: wordIDs ?? self.wordIDs,
            folderID: folderID ?? self.folderID,
            builtInKey: builtInKey
        )
    }
}
