import Foundation

public nonisolated struct RecordLessonResultsUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ results: LessonResults) async throws {
        guard !results.isEmpty else { return }
        try await repository.recordResults(results)
    }
}
