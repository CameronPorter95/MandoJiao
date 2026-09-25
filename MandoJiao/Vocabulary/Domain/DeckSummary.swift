import Foundation

/// A named subset of the library, by word identity.
nonisolated struct DeckSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let wordIDs: [UUID]

    var displayName: String { name.isEmpty ? "Untitled deck" : name }
}

nonisolated extension DeckSummary {
    func settingMembership(of wordID: UUID, to isIncluded: Bool) -> DeckSummary {
        var wordIDs = self.wordIDs.filter { $0 != wordID }
        if isIncluded { wordIDs.append(wordID) }
        return DeckSummary(id: id, name: name, createdAt: createdAt, wordIDs: wordIDs)
    }
}
