import DictionaryDomain
import Foundation

/// The library's words as the dictionary sees them, so a reading shows as saved.
public nonisolated struct VocabularySavedReadings: SavedReadingsRepository {
    public let repository: any VocabularyRepository

    public init(repository: any VocabularyRepository) {
        self.repository = repository
    }

    public func savedReadings() -> AsyncStream<[SavedReading]> {
        let vocabulary = repository.vocabulary()
        return AsyncStream { continuation in
            let task = Task {
                for await snapshot in vocabulary {
                    continuation.yield(snapshot.words.map { SavedReading(id: $0.id, hanzi: $0.hanzi, pinyin: $0.pinyin) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
