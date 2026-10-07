import Foundation

public nonisolated struct DeleteDeckUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// The deck's words stay in the library.
    public func callAsFunction(id: UUID) async throws {
        try await repository.deleteDeck(id: id)
    }
}
