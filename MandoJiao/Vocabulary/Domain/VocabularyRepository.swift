import Foundation

nonisolated protocol VocabularyRepository: Sendable {
    /// The current vocabulary, then again after every change made through this repository.
    func vocabulary() -> AsyncStream<Vocabulary>

    /// Nil `id` adds a new word.
    func saveWord(id: UUID?, draft: WordDraft) async throws
    func deleteWords(ids: [UUID]) async throws

    func createDeck(name: String) async throws
    func renameDeck(id: UUID, name: String) async throws
    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws
    func deleteDeck(id: UUID) async throws

    func recordResults(_ results: LessonResults) async throws
    func clearMistakes() async throws
}
