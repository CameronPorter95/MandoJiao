import Foundation

public nonisolated struct CreateFolderUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    /// A blank name creates nothing.
    public func callAsFunction(name: String, parentID: UUID? = nil) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try await repository.createFolder(name: name, parentID: parentID)
    }
}
