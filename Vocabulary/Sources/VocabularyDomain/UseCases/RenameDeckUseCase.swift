import Foundation

public nonisolated struct RenameDeckUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// Saved as typed. A deck with a blank name shows as untitled.
    public func callAsFunction(id: UUID, name: String) async throws {
        try await repository.renameDeck(id: id, name: name)
    }
}
