import Foundation

nonisolated struct ObserveVocabularyUseCase: Sendable {
    let repository: any VocabularyRepository

    func callAsFunction() -> AsyncStream<Vocabulary> {
        repository.vocabulary()
    }
}
