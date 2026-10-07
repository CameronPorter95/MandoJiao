import Foundation

public nonisolated struct ObserveVocabularyUseCase: Sendable {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> AsyncStream<Vocabulary> {
        repository.vocabulary()
    }
}
