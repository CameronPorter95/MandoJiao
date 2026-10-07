import DictionaryDomain
import Foundation

public nonisolated struct InstallHSKLevelUseCase: Sendable {
    public let hsk: any HSKRepository
    public let repository: any VocabularyRepository

    public init(hsk: any HSKRepository, repository: any VocabularyRepository) {
        self.hsk = hsk
        self.repository = repository
    }

    /// Adds the level, or restores whatever of it was deleted. `vocabulary` places a new
    /// HSK folder last at the top level.
    public func callAsFunction(level: Int, in vocabulary: Vocabulary) async throws {
        let plan = HSK.plan(level: level, words: try await hsk.words(), topLevelFolders: vocabulary.folders(in: nil).count)
        try await repository.install(plan)
    }
}
