import Foundation

nonisolated struct RenameDeckUseCase: Sendable {
    let repository: any VocabularyRepository

    /// Saved as typed. A deck with a blank name shows as untitled.
    func callAsFunction(id: UUID, name: String) async throws {
        try await repository.renameDeck(id: id, name: name)
    }
}
