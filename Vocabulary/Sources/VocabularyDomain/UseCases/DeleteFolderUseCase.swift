import Foundation

public nonisolated struct DeleteFolderUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// Every folder and deck beneath it goes too. The words stay in the library.
    public func callAsFunction(id: UUID) async throws {
        try await repository.deleteFolder(id: id)
    }
}
