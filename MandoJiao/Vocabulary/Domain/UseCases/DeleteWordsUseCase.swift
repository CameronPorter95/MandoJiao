import Foundation

nonisolated struct DeleteWordsUseCase: Sendable {
    let repository: any VocabularyRepository

    func callAsFunction(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await repository.deleteWords(ids: ids)
    }
}
