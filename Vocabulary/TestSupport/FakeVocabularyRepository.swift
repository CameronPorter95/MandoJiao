import Foundation
import CoreDomain
import VocabularyDomain

/// An in-memory repository that behaves like the real one, records every write, and
/// can be told to fail.
public actor FakeVocabularyRepository: VocabularyRepository {
    public private(set) var snapshot: Vocabulary
    public private(set) var writes: [String] = []
    public private(set) var recordedResults: [LessonResults] = []
    private var failure: VocabularyDomainError?
    private var subscribers: [UUID: AsyncStream<Vocabulary>.Continuation] = [:]

    public init(_ snapshot: Vocabulary = .empty) {
        self.snapshot = snapshot
    }

    public static let failure = VocabularyDomainError.persistence(
        model: DomainErrorModel(domain: "test", code: 1, description: "store failed")
    )

    public func failWrites(with error: VocabularyDomainError? = FakeVocabularyRepository.failure) {
        failure = error
    }

    public func replace(_ snapshot: Vocabulary) {
        self.snapshot = snapshot
        publish()
    }

    public nonisolated func vocabulary() -> AsyncStream<Vocabulary> {
        let (stream, continuation) = AsyncStream<Vocabulary>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in Task { await self?.unsubscribe(id) } }
        Task { await subscribe(id, continuation) }
        return stream
    }

    public func saveWord(id: UUID?, draft: WordDraft) throws {
        try write("saveWord \(id.map { _ in "existing" } ?? "new") \(draft.english)|\(draft.hanzi)|\(draft.pinyin)") {
            let word = Word(id: id ?? UUID(), english: draft.english, hanzi: draft.hanzi, pinyin: draft.pinyin)
            if let index = snapshot.words.firstIndex(where: { $0.id == id }) {
                snapshot.words[index] = word
            } else {
                snapshot.words.append(word)
            }
        }
    }

    public func deleteWords(ids: [UUID]) throws {
        try write("deleteWords \(ids.count)") { snapshot.words.removeAll { ids.contains($0.id) } }
    }

    public func createDeck(name: String) throws {
        try write("createDeck \(name)") {
            snapshot.decks.append(DeckSummary(id: UUID(), name: name, createdAt: .now, wordIDs: []))
        }
    }

    public func renameDeck(id: UUID, name: String) throws {
        try write("renameDeck \(name)") {
            guard let index = snapshot.decks.firstIndex(where: { $0.id == id }) else { return }
            let deck = snapshot.decks[index]
            snapshot.decks[index] = DeckSummary(id: id, name: name, createdAt: deck.createdAt, wordIDs: deck.wordIDs)
        }
    }

    public func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) throws {
        try write("setMembership \(isIncluded)") {
            guard let index = snapshot.decks.firstIndex(where: { $0.id == deckID }) else { return }
            snapshot.decks[index] = snapshot.decks[index].settingMembership(of: wordID, to: isIncluded)
        }
    }

    public func deleteDeck(id: UUID) throws {
        try write("deleteDeck") { snapshot.decks.removeAll { $0.id == id } }
    }

    public func recordResults(_ results: LessonResults) throws {
        try write("recordResults") { recordedResults.append(results) }
    }

    public func clearMistakes() throws {
        try write("clearMistakes") {
            snapshot.words = snapshot.words.map {
                Word(id: $0.id, english: $0.english, hanzi: $0.hanzi, pinyin: $0.pinyin, createdAt: $0.createdAt)
            }
        }
    }

    private func write(_ description: String, _ change: () -> Void) throws {
        if let failure { throw failure }
        writes.append(description)
        change()
        publish()
    }

    private func subscribe(_ id: UUID, _ continuation: AsyncStream<Vocabulary>.Continuation) {
        subscribers[id] = continuation
        continuation.yield(snapshot)
    }

    private func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
    }

    private func publish() {
        for continuation in subscribers.values { continuation.yield(snapshot) }
    }
}

public nonisolated enum Fixtures {
    public static let water = Word(english: "water", hanzi: "水", pinyin: "shuǐ")
    public static let tea = Word(english: "tea", hanzi: "茶", pinyin: "chá", missCount: 2, lastMissedAt: Date(timeIntervalSince1970: 100))
    public static let book = Word(english: "book", hanzi: "书", pinyin: "shū", missCount: 2, lastMissedAt: Date(timeIntervalSince1970: 200))
    public static let phone = Word(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī", missCount: 5)
    public static let green = Word(english: "green", hanzi: "绿", pinyin: "lǜ")
    public static let blank = Word(english: "", hanzi: "空")

    public static let words = [water, tea, book, phone, green, blank]

    /// Five usable words: exactly enough for a matching lesson.
    public static let fullDeck = DeckSummary(
        id: UUID(), name: "Full", createdAt: .now,
        wordIDs: [water.id, tea.id, book.id, phone.id, green.id]
    )
    public static let smallDeck = DeckSummary(id: UUID(), name: "Small", createdAt: .now, wordIDs: [water.id, blank.id])

    public static let vocabulary = Vocabulary(words: words, decks: [fullDeck, smallDeck])
}
