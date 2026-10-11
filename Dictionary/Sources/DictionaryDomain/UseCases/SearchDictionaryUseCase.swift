import Foundation

public nonisolated struct SearchDictionaryUseCase: Sendable {
    public static let limit = 100

    public let repository: any DictionaryRepository

    public init(repository: any DictionaryRepository) {
        self.repository = repository
    }

    /// Nothing for a blank query.
    public func callAsFunction(_ query: String) async throws -> [DictionarySearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await repository.search(trimmed, limit: Self.limit)
    }

    public func prepare() async {
        await repository.prepareSearch()
    }
}
