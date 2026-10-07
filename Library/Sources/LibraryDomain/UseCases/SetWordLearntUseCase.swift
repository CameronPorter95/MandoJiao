import Foundation

public nonisolated struct SetWordLearntUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    public func callAsFunction(wordID: UUID, isLearnt: Bool) async throws {
        try await repository.setLearnt(wordID: wordID, isLearnt: isLearnt)
    }
}
