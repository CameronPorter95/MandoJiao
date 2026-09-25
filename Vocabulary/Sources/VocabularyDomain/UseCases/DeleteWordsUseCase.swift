import Foundation

public nonisolated struct DeleteWordsUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    public func callAsFunction(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await repository.deleteWords(ids: ids)
    }
}
