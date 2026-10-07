import Foundation

public nonisolated struct LookUpDictionaryUseCase: Sendable {
    public let repository: any DictionaryRepository

    public init(repository: any DictionaryRepository) {
        self.repository = repository
    }

    /// Trims the Hanzi. Blank input is never a headword.
    public func callAsFunction(hanzi: String) async throws -> [DictionaryEntry] {
        let trimmed = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await repository.entries(forHanzi: trimmed)
    }
}
