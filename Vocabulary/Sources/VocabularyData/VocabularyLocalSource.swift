import CoreDomain
import CorePersistence
import Foundation
import VocabularyDomain

/// The store, in domain terms. Implementations throw `LocalStoreError` when the store
/// fails. An id that no longer exists is ignored rather than treated as a failure.
nonisolated protocol VocabularyLocalSource: Sendable {
    func snapshot() async throws -> Vocabulary
    func saveWord(id: UUID?, draft: WordDraft) async throws
    func deleteWords(ids: [UUID]) async throws
    func createDeck(name: String, folderID: UUID?) async throws
    func renameDeck(id: UUID, name: String) async throws
    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws
    func moveDeck(id: UUID, toFolder folderID: UUID?) async throws
    func deleteDeck(id: UUID) async throws
    func createFolder(name: String, parentID: UUID?) async throws
    func renameFolder(id: UUID, name: String) async throws
    func moveFolder(id: UUID, toParent parentID: UUID?) async throws
    func deleteFolder(id: UUID) async throws
    func recordResults(_ results: LessonResults) async throws
    func clearMistakes() async throws
}
