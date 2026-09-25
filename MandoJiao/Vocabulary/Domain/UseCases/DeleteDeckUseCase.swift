import Foundation

nonisolated struct DeleteDeckUseCase: Sendable {
    let repository: any VocabularyRepository

    /// The deck's words stay in the library.
    func callAsFunction(id: UUID) async throws {
        try await repository.deleteDeck(id: id)
    }
}
