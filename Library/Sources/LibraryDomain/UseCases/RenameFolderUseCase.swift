import Foundation

public nonisolated struct RenameFolderUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// Saved as typed. A folder with a blank name shows as untitled.
    public func callAsFunction(id: UUID, name: String) async throws {
        try await repository.renameFolder(id: id, name: name)
    }
}
