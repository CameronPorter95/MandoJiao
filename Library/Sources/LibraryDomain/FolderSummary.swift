import Foundation

/// Holds decks and other folders. Practising one draws from every deck beneath it.
public nonisolated struct FolderSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    /// Nil for a folder at the top level.
    public let parentID: UUID?
    /// Identifies a folder the app supplies, such as an HSK level, however it is renamed.
    public let builtInKey: String?
    /// When a lesson from it last had anything answered. Nil if it never has.
    public let lastPractisedAt: Date?

    public init(
        id: UUID,
        name: String,
        createdAt: Date,
        parentID: UUID? = nil,
        builtInKey: String? = nil,
        lastPractisedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.parentID = parentID
        self.builtInKey = builtInKey
        self.lastPractisedAt = lastPractisedAt
    }

    public var displayName: String { name.isEmpty ? "Untitled folder" : name }
}

public nonisolated extension FolderSummary {
    /// `parentID: .some(nil)` moves the folder to the top level.
    func with(name: String? = nil, parentID: UUID?? = nil) -> FolderSummary {
        FolderSummary(
            id: id,
            name: name ?? self.name,
            createdAt: createdAt,
            parentID: parentID ?? self.parentID,
            builtInKey: builtInKey,
            lastPractisedAt: lastPractisedAt
        )
    }
}
