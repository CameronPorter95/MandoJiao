import Foundation
import SwiftData
import Testing
import CoreDomain
import CorePersistence
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

@Suite("Vocabulary store, through the repository")
@MainActor
struct VocabularyRepositoryTests {
    /// Held for the life of the test. Letting the container go out of scope tears the
    /// store down underneath the repository.
    private let container: ModelContainer
    private let repository: VocabularyRepositoryImpl

    init() throws {
        container = try VocabularyStore.makeContainer(inMemory: true)
        repository = VocabularyRepositoryImpl(localSource: VocabularyLocalSourceImpl(modelContainer: container))
    }

    // MARK: - The mistakes list

    @Test("misses accumulate against every word involved")
    func missesAccumulate() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [ids.water: 2, ids.tea: 2], cleanSolves: [:]))

        let words = await current().byEnglish
        #expect(words["water"]?.missCount == 2)
        #expect(words["tea"]?.missCount == 2)
        #expect(words["water"]?.lastMissedAt != nil)
    }

    @Test("a word that was never missed stays clean")
    func cleanWordsStayClean() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [:], cleanSolves: [ids.book: 3]))

        let book = await current().byEnglish["book"]
        #expect(book?.missCount == 0)
        #expect(book?.lastMissedAt == nil)
    }

    @Test("solving a word later in the lesson that missed it does not cancel the miss")
    func recoveryDoesNotCancelAMiss() async throws {
        // Without this, a single miss would wipe itself out the moment the word came
        // round again, which happens constantly with a small pool, and the mistakes list
        // would stay permanently empty.
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [ids.water: 2], cleanSolves: [:]))
        try await repository.recordResults(LessonResults(misses: [ids.water: 1], cleanSolves: [ids.water: 2]))

        #expect(await current().byEnglish["water"]?.missCount == 3)
    }

    @Test("a clean solve works one mistake off the list")
    func cleanSolveDecrements() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [ids.tea: 2], cleanSolves: [:]))
        try await repository.recordResults(LessonResults(misses: [:], cleanSolves: [ids.tea: 1]))

        #expect(await current().byEnglish["tea"]?.missCount == 1)
    }

    @Test("a word at three mistakes takes three clean lessons to clear")
    func oneOffPerLesson() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [ids.water: 3], cleanSolves: [:]))

        for remaining in [2, 1, 0] {
            try await repository.recordResults(LessonResults(misses: [:], cleanSolves: [ids.water: 1]))
            #expect(await current().byEnglish["water"]?.missCount == remaining)
        }
    }

    @Test("clean solves cannot push a count below zero")
    func neverNegative() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [:], cleanSolves: [ids.book: 5]))
        #expect(await current().byEnglish["book"]?.missCount == 0)
    }

    @Test("clearing the list resets the count and the date")
    func clearAll() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [ids.water: 2, ids.tea: 1], cleanSolves: [:]))
        try await repository.clearMistakes()

        let words = await current().byEnglish
        #expect(words["water"]?.missCount == 0)
        #expect(words["water"]?.lastMissedAt == nil)
        #expect(words["tea"]?.missCount == 0)
    }

    // MARK: - Words and decks

    @Test("editing a word keeps its identity and its mistakes")
    func editingAWord() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.recordResults(LessonResults(misses: [ids.water: 1], cleanSolves: [:]))

        try await repository.saveWord(id: ids.water, draft: WordDraft(english: "cold water", hanzi: "冷水", pinyin: "lěngshuǐ"))

        let word = await current().words.first { $0.id == ids.water }
        #expect(word?.english == "cold water")
        #expect(word?.hanzi == "冷水")
        #expect(word?.missCount == 1)
    }

    @Test("a deck holds words by identity and can be renamed")
    func decks() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.createDeck(name: "Drinks", folderID: try await makeFolder())
        let deckID = try #require(await current().decks.first?.id)

        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: true)
        try await repository.setMembership(deckID: deckID, wordID: ids.tea, isIncluded: true)
        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: false)
        try await repository.renameDeck(id: deckID, name: "Hot drinks")

        let deck = try #require(await current().deck(id: deckID))
        #expect(deck.name == "Hot drinks")
        #expect(deck.wordIDs == [ids.tea])
    }

    @Test("renaming a deck or changing its words marks it edited, not created")
    func editedDate() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.createDeck(name: "Drinks", folderID: try await makeFolder())
        let created = try #require(await current().decks.first)

        try await Task.sleep(for: .milliseconds(20))
        try await repository.setMembership(deckID: created.id, wordID: ids.water, isIncluded: true)
        let added = try #require(await current().deck(id: created.id))
        #expect(added.editedAt > created.editedAt)

        try await Task.sleep(for: .milliseconds(20))
        try await repository.renameDeck(id: created.id, name: "Hot drinks")
        let renamed = try #require(await current().deck(id: created.id))
        #expect(renamed.editedAt > added.editedAt)
        #expect(renamed.createdAt == created.createdAt)
    }

    @Test("a word keeps every meaning in order, and one saved before meanings reads as its one")
    func meanings() async throws {
        try await repository.saveWord(id: nil, draft: WordDraft(meanings: ["to drink", "to shout"], hanzi: "喝"))
        let saved = try #require(await current().words.first)
        #expect(saved.meanings == ["to drink", "to shout"])

        try await repository.saveWord(id: saved.id, draft: WordDraft(meanings: ["to shout", "to drink"], hanzi: "喝"))
        #expect(await current().words.first?.meanings == ["to shout", "to drink"])
        let stored = try container.mainContext.fetch(FetchDescriptor<VocabWord>()).first
        #expect(stored?.english == "to shout")

        container.mainContext.insert(VocabWord(english: "water", hanzi: "水"))
        try container.mainContext.save()
        #expect(await current().words.first { $0.hanzi == "水" }?.meanings == ["water"])
    }

    @Test("deleting a deck leaves its words in the library")
    func deletingADeck() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.createDeck(name: "Drinks", folderID: try await makeFolder())
        let deckID = try #require(await current().decks.first?.id)
        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: true)

        try await repository.deleteDeck(id: deckID)

        let vocabulary = await current()
        #expect(vocabulary.decks.isEmpty)
        #expect(vocabulary.words.count == 3)
    }

    @Test("deleting a word takes it out of its decks")
    func deletingAWord() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.createDeck(name: "Drinks", folderID: try await makeFolder())
        let deckID = try #require(await current().decks.first?.id)
        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: true)

        try await repository.deleteWords(ids: [ids.water])

        let vocabulary = await current()
        #expect(vocabulary.words.count == 2)
        #expect(vocabulary.deck(id: deckID)?.wordIDs.isEmpty == true)
    }

    @Test("folders hold decks and folders, move, and delete everything beneath them, keeping the words")
    func folders() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.createFolder(name: "HSK", parentID: nil)
        let hsk = try #require(await current().folders.first { $0.name == "HSK" }?.id)
        try await repository.createFolder(name: "Level 1", parentID: hsk)
        let level1 = try #require(await current().folders.first { $0.name == "Level 1" }?.id)
        try await repository.createDeck(name: "Part 1", folderID: level1)
        let part1 = try #require(await current().decks.first { $0.name == "Part 1" }?.id)
        try await repository.setMembership(deckID: part1, wordID: ids.water, isIncluded: true)
        try await repository.renameFolder(id: level1, name: "HSK 1")

        var vocabulary = await current()
        #expect(vocabulary.path(to: level1).map(\.name) == ["HSK", "HSK 1"])
        #expect(vocabulary.words(in: try #require(vocabulary.folder(id: hsk))).map(\.english) == ["water"])

        try await repository.moveDeck(id: part1, toFolder: hsk, at: nil)
        #expect(await current().deck(id: part1)?.folderID == hsk)
        try await repository.moveDeck(id: part1, toFolder: nil, at: nil)
        #expect(await current().deck(id: part1)?.folderID == hsk)
        try await repository.moveDeck(id: part1, toFolder: level1, at: nil)
        try await repository.moveFolder(id: level1, toParent: nil, at: nil)
        #expect(await current().folder(id: level1)?.parentID == nil)
        try await repository.moveFolder(id: level1, toParent: hsk, at: nil)

        try await repository.deleteFolder(id: hsk)
        vocabulary = await current()
        #expect(vocabulary.folders.isEmpty)
        #expect(vocabulary.decks.isEmpty)
        #expect(vocabulary.words.count == 3)
    }

    @Test("folders and decks keep the order they are moved into, after the store is read again")
    func order() async throws {
        for name in ["A", "B", "C"] { try await repository.createFolder(name: name, parentID: nil) }
        let ids = Dictionary(uniqueKeysWithValues: await current().folders.map { ($0.name, $0.id) })
        #expect(await current().folders(in: nil).map(\.name) == ["A", "B", "C"])

        try await repository.moveFolder(id: ids["C"]!, toParent: nil, at: 0)
        try await repository.moveFolder(id: ids["A"]!, toParent: nil, at: 1)
        #expect(await current().folders(in: nil).map(\.name) == ["C", "A", "B"])

        for name in ["x", "y"] { try await repository.createDeck(name: name, folderID: ids["B"]!) }
        let y = try #require(await current().decks.first { $0.name == "y" }?.id)
        try await repository.moveDeck(id: y, toFolder: ids["B"], at: 0)

        let reread = try await VocabularyLocalSourceImpl(modelContainer: container).snapshot()
        #expect(reread.folders(in: nil).map(\.name) == ["C", "A", "B"])
        #expect(reread.decks(in: ids["B"]).map(\.name) == ["y", "x"])
    }

    @Test("a fresh store has the starter decks inside a built-in Starter folder")
    func seeding() async throws {
        VocabularyStore.seedIfNeeded(container)
        let vocabulary = await current()

        let starter = try #require(vocabulary.folders.first { $0.builtInKey == SampleVocabulary.builtInKey })
        #expect(vocabulary.folders(in: nil).first == starter)
        #expect(starter.name == "Starter")
        #expect(starter.builtInKey == SampleVocabulary.builtInKey)
        #expect(vocabulary.decks(in: starter.id).map(\.name) == SampleVocabulary.deckPlan.map(\.name))
        #expect(vocabulary.decks(in: nil).isEmpty)
    }

    @Test("the store refuses to move a folder into itself or beneath itself")
    func folderCycles() async throws {
        try await repository.createFolder(name: "Parent", parentID: nil)
        let parent = try #require(await current().folders.first { $0.name == "Parent" }?.id)
        try await repository.createFolder(name: "Child", parentID: parent)
        let child = try #require(await current().folders.first { $0.name == "Child" }?.id)

        try await repository.moveFolder(id: parent, toParent: child, at: nil)
        try await repository.moveFolder(id: parent, toParent: parent, at: nil)

        #expect(await current().folder(id: parent)?.parentID == nil)
        #expect(await current().folder(id: child)?.parentID == parent)
    }

    @Test("an id that no longer exists is ignored rather than failing")
    func missingIDs() async throws {
        _ = try await addWaterTeaBook()
        try await repository.renameDeck(id: UUID(), name: "Nowhere")
        try await repository.setMembership(deckID: UUID(), wordID: UUID(), isIncluded: true)
        try await repository.saveWord(id: UUID(), draft: WordDraft(english: "ghost", hanzi: "鬼"))

        #expect(await current().words.count == 3)
    }

    @Test("a subscriber hears about every change")
    func observing() async throws {
        let log = SnapshotLog(repository.vocabulary())
        #expect(await waitUntil { log.snapshots.last?.words.isEmpty == true })

        try await repository.saveWord(id: nil, draft: WordDraft(english: "water", hanzi: "水"))

        #expect(await waitUntil { log.snapshots.last?.words.map(\.english) == ["water"] })
    }

    @Test("every screen shares one repository per store, so one screen's write reaches another's list")
    func sharedAcrossScreens() async throws {
        // Factories are stateless and each asks for the repository. If each got its own,
        // the word editor would save and the library behind it would never hear.
        let library = VocabularyStore.repository(for: container)
        let editor = VocabularyStore.repository(for: container)
        let log = SnapshotLog(library.vocabulary())
        #expect(await waitUntil { log.snapshots.last?.words.isEmpty == true })

        try await editor.saveWord(id: nil, draft: WordDraft(english: "water", hanzi: "水"))

        #expect(await waitUntil { log.snapshots.last?.words.map(\.english) == ["water"] })
    }

    // MARK: - Helpers

    private func addWaterTeaBook() async throws -> (water: UUID, tea: UUID, book: UUID) {
        for (english, hanzi) in [("water", "水"), ("tea", "茶"), ("book", "书")] {
            try await repository.saveWord(id: nil, draft: WordDraft(english: english, hanzi: hanzi))
        }
        let words = await current().byEnglish
        return (try #require(words["water"]?.id), try #require(words["tea"]?.id), try #require(words["book"]?.id))
    }

    /// A fresh subscription always starts with the current snapshot.
    private func current() async -> Vocabulary {
        for await vocabulary in repository.vocabulary() { return vocabulary }
        return .empty
    }
}

@Suite("Vocabulary repository error classification")
struct VocabularyRepositoryClassificationTests {
    @Test("a store failure becomes a persistence error")
    func storeFailure() async {
        let repository = VocabularyRepositoryImpl(localSource: FailingLocalSource(error: LocalStoreError(CocoaError(.fileWriteUnknown))))
        await #expect(throws: VocabularyDomainError.persistence(model: DomainErrorModel(CocoaError(.fileWriteUnknown)))) {
            try await repository.clearMistakes()
        }
    }

    @Test("anything else becomes an unexpected error")
    func otherFailure() async {
        struct Oops: Error {}
        let repository = VocabularyRepositoryImpl(localSource: FailingLocalSource(error: Oops()))
        await #expect(throws: VocabularyDomainError.unexpected(model: DomainErrorModel(Oops()))) {
            try await repository.clearMistakes()
        }
    }

    @Test("cancellation stays cancellation")
    func cancellation() async {
        let repository = VocabularyRepositoryImpl(localSource: FailingLocalSource(error: CancellationError()))
        await #expect(throws: CancellationError.self) {
            try await repository.clearMistakes()
        }
    }
}

@MainActor
private final class SnapshotLog {
    private(set) var snapshots: [Vocabulary] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<Vocabulary>) {
        task = Task { [weak self] in
            for await snapshot in stream { self?.snapshots.append(snapshot) }
        }
    }

    deinit { task?.cancel() }
}

private extension VocabularyRepositoryTests {
    /// Somewhere to put a deck, since every deck lives in a folder.
    func makeFolder(_ name: String = "Box") async throws -> UUID {
        try await repository.createFolder(name: name, parentID: nil)
        return try #require(await current().folders.first { $0.name == name }?.id)
    }
}

private struct FailingLocalSource: VocabularyLocalSource {
    let error: any Error & Sendable

    func snapshot() async throws -> Vocabulary { throw error }
    func saveWord(id: UUID?, draft: WordDraft) async throws { throw error }
    func deleteWords(ids: [UUID]) async throws { throw error }
    func createDeck(name: String, folderID: UUID) async throws { throw error }
    func renameDeck(id: UUID, name: String) async throws { throw error }
    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws { throw error }
    func moveDeck(id: UUID, toFolder folderID: UUID?, at index: Int?) async throws { throw error }
    func deleteDeck(id: UUID) async throws { throw error }
    func createFolder(name: String, parentID: UUID?) async throws { throw error }
    func renameFolder(id: UUID, name: String) async throws { throw error }
    func moveFolder(id: UUID, toParent parentID: UUID?, at index: Int?) async throws { throw error }
    func deleteFolder(id: UUID) async throws { throw error }
    func install(_ plan: BuiltInPlan) async throws { throw error }
    func recordResults(_ results: LessonResults) async throws { throw error }
    func clearMistakes() async throws { throw error }
}

private extension Vocabulary {
    var byEnglish: [String: Word] {
        Dictionary(words.map { ($0.english, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
