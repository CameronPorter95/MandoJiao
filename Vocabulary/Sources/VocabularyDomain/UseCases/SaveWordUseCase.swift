import Foundation

public nonisolated struct SaveWordUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// Trims every field. An incomplete draft is not saved.
    public func callAsFunction(id: UUID?, draft: WordDraft) async throws {
        guard draft.isComplete else { return }
        try await repository.saveWord(id: id, draft: draft.trimmed)
    }
}
