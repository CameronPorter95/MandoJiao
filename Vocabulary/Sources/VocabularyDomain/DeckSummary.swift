import Foundation

/// A named subset of the library, by word identity.
public nonisolated struct DeckSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let wordIDs: [UUID]

    public init(id: UUID, name: String, createdAt: Date, wordIDs: [UUID]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.wordIDs = wordIDs
    }

    public var displayName: String { name.isEmpty ? "Untitled deck" : name }
}

public nonisolated extension DeckSummary {
    func settingMembership(of wordID: UUID, to isIncluded: Bool) -> DeckSummary {
        var wordIDs = self.wordIDs.filter { $0 != wordID }
        if isIncluded { wordIDs.append(wordID) }
        return DeckSummary(id: id, name: name, createdAt: createdAt, wordIDs: wordIDs)
    }
}
