import Foundation

public nonisolated struct MoveDeckUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// A nil index puts the deck last.
    public func callAsFunction(id: UUID, toFolder folderID: UUID, at index: Int? = nil) async throws {
        try await repository.moveDeck(id: id, toFolder: folderID, at: index)
    }
}
