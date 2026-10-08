import Foundation

public nonisolated struct FindExamplesUseCase: Sendable {
    public let repository: any ExampleRepository

    public init(repository: any ExampleRepository) {
        self.repository = repository
    }

    /// Trims both. Nothing for blank Hanzi.
    public func callAsFunction(hanzi: String, pinyin: String) async throws -> [ExampleSentence] {
        let hanzi = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hanzi.isEmpty else { return [] }
        return try await repository.examples(forHanzi: hanzi, pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
