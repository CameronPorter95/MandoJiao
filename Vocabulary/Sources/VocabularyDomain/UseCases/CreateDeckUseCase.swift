import Foundation

public nonisolated struct CreateDeckUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// A blank name creates nothing.
    public func callAsFunction(name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try await repository.createDeck(name: name)
    }
}
