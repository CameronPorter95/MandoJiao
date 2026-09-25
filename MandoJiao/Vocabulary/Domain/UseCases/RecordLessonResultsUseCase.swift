import Foundation

nonisolated struct RecordLessonResultsUseCase: Sendable {
    let repository: any VocabularyRepository

    func callAsFunction(_ results: LessonResults) async throws {
        guard !results.isEmpty else { return }
        try await repository.recordResults(results)
    }
}
