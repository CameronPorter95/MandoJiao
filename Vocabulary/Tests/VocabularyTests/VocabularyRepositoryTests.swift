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
        try await repository.createDeck(name: "Drinks")
        let deckID = try #require(await current().decks.first?.id)

        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: true)
        try await repository.setMembership(deckID: deckID, wordID: ids.tea, isIncluded: true)
        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: false)
        try await repository.renameDeck(id: deckID, name: "Hot drinks")

        let deck = try #require(await current().deck(id: deckID))
        #expect(deck.name == "Hot drinks")
        #expect(deck.wordIDs == [ids.tea])
    }

    @Test("deleting a deck leaves its words in the library")
    func deletingADeck() async throws {
        let ids = try await addWaterTeaBook()
        try await repository.createDeck(name: "Drinks")
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
        try await repository.createDeck(name: "Drinks")
        let deckID = try #require(await current().decks.first?.id)
        try await repository.setMembership(deckID: deckID, wordID: ids.water, isIncluded: true)

        try await repository.deleteWords(ids: [ids.water])

        let vocabulary = await current()
        #expect(vocabulary.words.count == 2)
        #expect(vocabulary.deck(id: deckID)?.wordIDs.isEmpty == true)
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

private struct FailingLocalSource: VocabularyLocalSource {
    let error: any Error & Sendable

    func snapshot() async throws -> Vocabulary { throw error }
    func saveWord(id: UUID?, draft: WordDraft) async throws { throw error }
    func deleteWords(ids: [UUID]) async throws { throw error }
    func createDeck(name: String) async throws { throw error }
    func renameDeck(id: UUID, name: String) async throws { throw error }
    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) async throws { throw error }
    func deleteDeck(id: UUID) async throws { throw error }
    func recordResults(_ results: LessonResults) async throws { throw error }
    func clearMistakes() async throws { throw error }
}

private extension Vocabulary {
    var byEnglish: [String: Word] {
        Dictionary(words.map { ($0.english, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
