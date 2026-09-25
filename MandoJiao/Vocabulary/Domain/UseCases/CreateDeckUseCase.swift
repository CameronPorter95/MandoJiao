import Foundation

nonisolated struct CreateDeckUseCase: Sendable {
    let repository: any VocabularyRepository

    /// A blank name creates nothing.
    func callAsFunction(name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try await repository.createDeck(name: name)
    }
}
