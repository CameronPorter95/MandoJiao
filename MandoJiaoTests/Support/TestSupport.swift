import Foundation
@testable import MandoJiao

/// Polls until `condition` holds, or gives up after `timeout`.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while await !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}

/// Long enough for any queued work to land, for asserting that something did not happen.
func settle() async {
    try? await Task.sleep(for: .milliseconds(100))
}

/// Collects a view model's effects as they arrive.
@MainActor
final class EffectLog<Effect: Equatable> {
    private(set) var effects: [Effect] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<Effect>) {
        task = Task { [weak self] in
            for await effect in stream { self?.effects.append(effect) }
        }
    }

    deinit { task?.cancel() }

    func contains(_ effect: Effect) async -> Bool {
        await waitUntil { self.effects.contains(effect) }
    }

    func equals(_ expected: [Effect]) async -> Bool {
        await waitUntil { self.effects == expected }
    }
}

/// An in-memory repository that behaves like the real one, records every write, and
/// can be told to fail.
actor FakeVocabularyRepository: VocabularyRepository {
    private(set) var snapshot: Vocabulary
    private(set) var writes: [String] = []
    private(set) var recordedResults: [LessonResults] = []
    private var failure: VocabularyDomainError?
    private var subscribers: [UUID: AsyncStream<Vocabulary>.Continuation] = [:]

    init(_ snapshot: Vocabulary = .empty) {
        self.snapshot = snapshot
    }

    static let failure = VocabularyDomainError.persistence(
        model: DomainErrorModel(domain: "test", code: 1, description: "store failed")
    )

    func failWrites(with error: VocabularyDomainError? = FakeVocabularyRepository.failure) {
        failure = error
    }

    func replace(_ snapshot: Vocabulary) {
        self.snapshot = snapshot
        publish()
    }

    nonisolated func vocabulary() -> AsyncStream<Vocabulary> {
        let (stream, continuation) = AsyncStream<Vocabulary>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in Task { await self?.unsubscribe(id) } }
        Task { await subscribe(id, continuation) }
        return stream
    }

    func saveWord(id: UUID?, draft: WordDraft) throws {
        try write("saveWord \(id.map { _ in "existing" } ?? "new") \(draft.english)|\(draft.hanzi)|\(draft.pinyin)") {
            let word = Word(id: id ?? UUID(), english: draft.english, hanzi: draft.hanzi, pinyin: draft.pinyin)
            if let index = snapshot.words.firstIndex(where: { $0.id == id }) {
                snapshot.words[index] = word
            } else {
                snapshot.words.append(word)
            }
        }
    }

    func deleteWords(ids: [UUID]) throws {
        try write("deleteWords \(ids.count)") { snapshot.words.removeAll { ids.contains($0.id) } }
    }

    func createDeck(name: String) throws {
        try write("createDeck \(name)") {
            snapshot.decks.append(DeckSummary(id: UUID(), name: name, createdAt: .now, wordIDs: []))
        }
    }

    func renameDeck(id: UUID, name: String) throws {
        try write("renameDeck \(name)") {
            guard let index = snapshot.decks.firstIndex(where: { $0.id == id }) else { return }
            let deck = snapshot.decks[index]
            snapshot.decks[index] = DeckSummary(id: id, name: name, createdAt: deck.createdAt, wordIDs: deck.wordIDs)
        }
    }

    func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) throws {
        try write("setMembership \(isIncluded)") {
            guard let index = snapshot.decks.firstIndex(where: { $0.id == deckID }) else { return }
            snapshot.decks[index] = snapshot.decks[index].settingMembership(of: wordID, to: isIncluded)
        }
    }

    func deleteDeck(id: UUID) throws {
        try write("deleteDeck") { snapshot.decks.removeAll { $0.id == id } }
    }

    func recordResults(_ results: LessonResults) throws {
        try write("recordResults") { recordedResults.append(results) }
    }

    func clearMistakes() throws {
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

nonisolated enum Fixtures {
    static let water = Word(english: "water", hanzi: "水", pinyin: "shuǐ")
    static let tea = Word(english: "tea", hanzi: "茶", pinyin: "chá", missCount: 2, lastMissedAt: Date(timeIntervalSince1970: 100))
    static let book = Word(english: "book", hanzi: "书", pinyin: "shū", missCount: 2, lastMissedAt: Date(timeIntervalSince1970: 200))
    static let phone = Word(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī", missCount: 5)
    static let green = Word(english: "green", hanzi: "绿", pinyin: "lǜ")
    static let blank = Word(english: "", hanzi: "空")

    static let words = [water, tea, book, phone, green, blank]

    /// Five usable words: exactly enough for a matching lesson.
    static let fullDeck = DeckSummary(
        id: UUID(), name: "Full", createdAt: .now,
        wordIDs: [water.id, tea.id, book.id, phone.id, green.id]
    )
    static let smallDeck = DeckSummary(id: UUID(), name: "Small", createdAt: .now, wordIDs: [water.id, blank.id])

    static let vocabulary = Vocabulary(words: words, decks: [fullDeck, smallDeck])
}
