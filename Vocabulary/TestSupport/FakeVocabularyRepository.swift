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

    public func saveWord(id: UUID?, draft: WordDraft, deckID: UUID?) throws {
        let deck = id == nil ? deckID.flatMap(snapshot.deck(id:)) : nil
        try write("saveWord \(id.map { _ in "existing" } ?? "new") \(draft.meanings.joined(separator: "; "))|\(draft.hanzi)|\(draft.pinyin)\(deck.map { " into \($0.name)" } ?? "")") {
            let word = Word(id: id ?? UUID(), meanings: draft.meanings, hanzi: draft.hanzi, pinyin: draft.pinyin)
            if let index = snapshot.words.firstIndex(where: { $0.id == id }) {
                snapshot.words[index] = word
            } else {
                snapshot.words.append(word)
                if let deck, let index = snapshot.decks.firstIndex(of: deck) {
                    snapshot.decks[index] = deck.settingMembership(of: word.id, to: true)
                }
            }
        }
    }

    public func deleteWords(ids: [UUID]) throws {
        try write("deleteWords \(ids.count)") { snapshot.words.removeAll { ids.contains($0.id) } }
    }

    public func createDeck(name: String, folderID: UUID) throws {
        try write("createDeck \(name)\(inside(folderID))") {
            guard snapshot.folder(id: folderID) != nil else { return }
            snapshot.decks.append(DeckSummary(id: UUID(), name: name, createdAt: .now, wordIDs: [], folderID: folderID))
        }
    }

    public func renameDeck(id: UUID, name: String) throws {
        try write("renameDeck \(name)") {
            guard let index = snapshot.decks.firstIndex(where: { $0.id == id }) else { return }
            snapshot.decks[index] = snapshot.decks[index].with(name: name, editedAt: .now)
        }
    }

    public func setMembership(deckID: UUID, wordID: UUID, isIncluded: Bool) throws {
        try write("setMembership \(isIncluded)") {
            guard let index = snapshot.decks.firstIndex(where: { $0.id == deckID }) else { return }
            snapshot.decks[index] = snapshot.decks[index].settingMembership(of: wordID, to: isIncluded)
        }
    }

    public func moveDeck(id: UUID, toFolder folderID: UUID?, at index: Int?) throws {
        try write("moveDeck \(snapshot.deck(id: id)?.name ?? "?") to \(destination(folderID))\(at(index))") {
            snapshot = snapshot.movingDeck(id, into: folderID, at: index)
        }
    }

    public func deleteDeck(id: UUID) throws {
        try write("deleteDeck") { snapshot.decks.removeAll { $0.id == id } }
    }

    public func createFolder(name: String, parentID: UUID?) throws {
        try write("createFolder \(name)\(inside(parentID))") {
            if let parentID, snapshot.folder(id: parentID) == nil { return }
            snapshot.folders.append(FolderSummary(id: UUID(), name: name, createdAt: .now, parentID: parentID))
        }
    }

    public func renameFolder(id: UUID, name: String) throws {
        try write("renameFolder \(name)") {
            guard let index = snapshot.folders.firstIndex(where: { $0.id == id }) else { return }
            snapshot.folders[index] = snapshot.folders[index].with(name: name)
        }
    }

    public func moveFolder(id: UUID, toParent parentID: UUID?, at index: Int?) throws {
        try write("moveFolder \(snapshot.folder(id: id)?.name ?? "?") to \(destination(parentID))\(at(index))") {
            snapshot = snapshot.movingFolder(id, into: parentID, at: index)
        }
    }

    public func deleteFolder(id: UUID) throws {
        try write("deleteFolder") {
            let folders = Set([id] + snapshot.folders(beneath: id).map(\.id))
            snapshot.folders.removeAll { folders.contains($0.id) }
            snapshot.decks.removeAll { $0.folderID.map(folders.contains) ?? false }
        }
    }

    public func install(_ plan: BuiltInPlan) throws {
        try write("install \(plan.decks.count) decks") {
            var folders = Dictionary(
                snapshot.folders.compactMap { folder in folder.builtInKey.map { ($0, folder.id) } },
                uniquingKeysWith: { first, _ in first }
            )
            for planned in plan.folders where folders[planned.key] == nil {
                let parentID = planned.parentKey.flatMap { folders[$0] }
                if planned.parentKey != nil, parentID == nil { continue }
                let folder = FolderSummary(id: UUID(), name: planned.name, createdAt: .now, parentID: parentID, builtInKey: planned.key)
                snapshot.folders.append(folder)
                folders[planned.key] = folder.id
            }
            let present = Set(snapshot.decks.compactMap(\.builtInKey))
            for planned in plan.decks where !present.contains(planned.key) {
                guard let folderID = folders[planned.folderKey] else { continue }
                let wordIDs = planned.words.map { draft in
                    if let existing = snapshot.words.first(where: { $0.hanzi == draft.hanzi }) { return existing.id }
                    let word = Word(english: draft.english, hanzi: draft.hanzi, pinyin: draft.pinyin)
                    snapshot.words.append(word)
                    return word.id
                }
                snapshot.decks.append(DeckSummary(
                    id: UUID(), name: planned.name, createdAt: .now, wordIDs: wordIDs, folderID: folderID, builtInKey: planned.key
                ))
            }
        }
    }

    public func recordResults(_ results: LessonResults) throws {
        try write("recordResults") {
            recordedResults.append(results)
            switch results.source {
            case .deck(let id):
                guard let index = snapshot.decks.firstIndex(where: { $0.id == id }) else { return }
                let deck = snapshot.decks[index]
                snapshot.decks[index] = DeckSummary(
                    id: deck.id, name: deck.name, createdAt: deck.createdAt, editedAt: deck.editedAt,
                    wordIDs: deck.wordIDs, folderID: deck.folderID, builtInKey: deck.builtInKey, lastPractisedAt: .now
                )
            case .folder(let id):
                guard let index = snapshot.folders.firstIndex(where: { $0.id == id }) else { return }
                let folder = snapshot.folders[index]
                snapshot.folders[index] = FolderSummary(
                    id: folder.id, name: folder.name, createdAt: folder.createdAt, parentID: folder.parentID,
                    builtInKey: folder.builtInKey, lastPractisedAt: .now
                )
            case nil:
                break
            }
        }
    }

    public func clearMistakes() throws {
        try write("clearMistakes") {
            snapshot.words = snapshot.words.map {
                Word(id: $0.id, meanings: $0.meanings, hanzi: $0.hanzi, pinyin: $0.pinyin, createdAt: $0.createdAt)
            }
        }
    }

    private func inside(_ folderID: UUID?) -> String {
        folderID.flatMap(snapshot.folder(id:)).map { " inside \($0.name)" } ?? ""
    }

    private func at(_ index: Int?) -> String {
        index.map { " at \($0)" } ?? ""
    }

    private func destination(_ folderID: UUID?) -> String {
        folderID.flatMap(snapshot.folder(id:))?.name ?? "top level"
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

    public static let starter = FolderSummary(id: UUID(), name: "Starter", createdAt: .now, builtInKey: "starter")

    /// Five usable words: exactly enough for a matching lesson.
    public static let fullDeck = DeckSummary(
        id: UUID(), name: "Full", createdAt: .now,
        wordIDs: [water.id, tea.id, book.id, phone.id, green.id], folderID: starter.id
    )
    public static let smallDeck = DeckSummary(
        id: UUID(), name: "Small", createdAt: .now, wordIDs: [water.id, blank.id], folderID: starter.id
    )

    public static let vocabulary = Vocabulary(words: words, decks: [fullDeck, smallDeck], folders: [starter])

    /// Starter holds Full. HSK holds Level 1, which holds two decks sharing tea. Empty holds nothing.
    public static let hsk = FolderSummary(id: UUID(), name: "HSK", createdAt: .now)
    public static let level1 = FolderSummary(id: UUID(), name: "Level 1", createdAt: .now, parentID: hsk.id)
    public static let part1 = DeckSummary(
        id: UUID(), name: "Part 1", createdAt: .now, wordIDs: [water.id, tea.id], folderID: level1.id
    )
    public static let part2 = DeckSummary(
        id: UUID(), name: "Part 2", createdAt: .now, wordIDs: [tea.id, book.id, phone.id, green.id], folderID: level1.id
    )
    public static let emptyFolder = FolderSummary(id: UUID(), name: "Empty", createdAt: .now)

    public static let nested = Vocabulary(
        words: words,
        decks: [fullDeck, part1, part2],
        folders: [starter, hsk, level1, emptyFolder]
    )
}
