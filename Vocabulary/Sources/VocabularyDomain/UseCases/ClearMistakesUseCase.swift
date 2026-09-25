import Foundation

public nonisolated struct ClearMistakesUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// Marks every word as learned.
    public func callAsFunction() async throws {
        try await repository.clearMistakes()
    }
}
