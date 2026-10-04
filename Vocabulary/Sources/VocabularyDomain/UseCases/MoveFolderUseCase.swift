import Foundation

public nonisolated struct MoveFolderUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// Nil `parentID` moves the folder to the top level, and a nil index puts it last.
    public func callAsFunction(id: UUID, toParent parentID: UUID?, at index: Int? = nil) async throws {
        try await repository.moveFolder(id: id, toParent: parentID, at: index)
    }
}
