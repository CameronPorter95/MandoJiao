import Foundation

nonisolated struct SaveWordUseCase: Sendable {
    let repository: any VocabularyRepository

    /// Trims every field. An incomplete draft is not saved.
    func callAsFunction(id: UUID?, draft: WordDraft) async throws {
        guard draft.isComplete else { return }
        try await repository.saveWord(id: id, draft: draft.trimmed)
    }
}
