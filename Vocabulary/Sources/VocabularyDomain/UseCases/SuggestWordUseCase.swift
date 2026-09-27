import Foundation

public nonisolated struct SuggestWordUseCase: Sendable {
    public let repository: any LexiconRepository

    public init(repository: any LexiconRepository) {
        self.repository = repository
    }

    /// Trims the Hanzi. Nothing is suggested for blank input.
    public func callAsFunction(hanzi: String) async throws -> WordSuggestion? {
        let trimmed = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try await repository.suggestion(forHanzi: trimmed)
    }
}
