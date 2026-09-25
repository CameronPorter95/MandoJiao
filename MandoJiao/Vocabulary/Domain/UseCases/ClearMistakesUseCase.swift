import Foundation

nonisolated struct ClearMistakesUseCase: Sendable {
    let repository: any VocabularyRepository

    /// Marks every word as learned.
    func callAsFunction() async throws {
        try await repository.clearMistakes()
    }
}
