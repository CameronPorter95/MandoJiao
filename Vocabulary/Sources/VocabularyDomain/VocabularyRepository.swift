import Foundation

public nonisolated protocol VocabularyRepository: Sendable {
    /// The current vocabulary, then again after every change made through this repository.
    func vocabulary() -> AsyncStream<Vocabulary>

    /// Nil `id` adds a new word, which also joins the deck `deckID` names, if it exists.
    /// `deckID` is ignored for a word already saved.
    func saveWord(id: UUID?, draft: WordDraft, deckID: UUID?) async throws
    func deleteWords(ids: [UUID]) async throws

    /// A deck always lives in a folder. Ignored when the folder does not exist.
    func createDeck(name: String, folderID: UUID) async throws
    func renameDeck(id: UUID, name: String) async throws
    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws
    /// As `Vocabulary.movingDeck` describes. Ignored where `canMoveDeck` is false.
    func moveDeck(id: UUID, toFolder folderID: UUID?, at index: Int?) async throws
    /// The deck's words stay in the library.
    func deleteDeck(id: UUID) async throws

    /// A nil parent means the top level, here and below.
    func createFolder(name: String, parentID: UUID?) async throws
    func renameFolder(id: UUID, name: String) async throws
    /// As `Vocabulary.movingFolder` describes. Ignored where `canMoveFolder` is false.
    func moveFolder(id: UUID, toParent parentID: UUID?, at index: Int?) async throws
    /// Deletes every folder and deck beneath it too. Words stay in the library.
    func deleteFolder(id: UUID) async throws

    /// Creates what the plan has and the library lacks, by key. Never changes anything present.
    func install(_ plan: BuiltInPlan) async throws

    func recordResults(_ results: LessonResults) async throws
    /// Learnt makes it known at once, as `WordMemory.markedLearnt` describes; not learnt
    /// keeps its strength.
    func setLearnt(wordID: UUID, isLearnt: Bool) async throws
    func clearMistakes() async throws
}
