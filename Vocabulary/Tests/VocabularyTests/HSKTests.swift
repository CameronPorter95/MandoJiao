import Foundation
import SwiftData
import Testing
import CoreDomain
@testable import VocabularyDomain
@testable import VocabularyData

/// Against the bundled list, so a regenerated `HSK.tsv` that changes a level fails here.
@Suite("HSK")
nonisolated struct HSKTests {
    private let words = try! BundledHSK.words()

    @Test("each level has the 2025 revision's word count")
    func counts() {
        let counts = Dictionary(grouping: words, by: \.level).mapValues(\.count)
        #expect(counts == [1: 294, 2: 197, 3: 487, 4: 972, 5: 1547, 6: 1684, 7: 4876])
        #expect(words.allSatisfy { !$0.pinyin.isEmpty && !$0.english.isEmpty })
        #expect(Set(words.map(\.hanzi)).count == words.count)
    }

    @Test("cost: a character's reading is the lexicon's, which misses the everyday one for some", arguments: [
        ("得", "dé"), ("长", "zhǎng"), ("教", "jiào"),
    ])
    func readings(hanzi: String, pinyin: String) {
        #expect(words.first { $0.hanzi == hanzi }?.pinyin == pinyin)
    }

    @Test("a level splits evenly into decks of at most 50, most common words first")
    func plan() {
        let hsk1 = HSK.plan(level: 1, words: words, topLevelFolders: 1)
        #expect(hsk1.decks.map(\.words.count) == [49, 49, 49, 49, 49, 49])
        #expect(hsk1.decks.map(\.name).prefix(2) == ["HSK 1 · 1", "HSK 1 · 2"])
        #expect(hsk1.decks.first?.words.first?.hanzi == "的")
        #expect(hsk1.decks.map(\.key).last == "hsk/1/6")
        #expect(hsk1.folders.map(\.key) == ["hsk", "hsk/1"])

        #expect(HSK.plan(level: 2, words: words, topLevelFolders: 1).decks.map(\.words.count) == [50, 49, 49, 49])
        #expect(HSK.plan(level: 7, words: words, topLevelFolders: 1).folders.last?.name == "HSK 7-9")
    }
}

@Suite("Installing built-in decks")
@MainActor
struct BuiltInInstallTests {
    private let container: ModelContainer
    private let repository: VocabularyRepositoryImpl
    private let words = try! BundledHSK.words()

    init() throws {
        container = try VocabularyStore.makeContainer(inMemory: true)
        repository = VocabularyRepositoryImpl(localSource: VocabularyLocalSourceImpl(modelContainer: container))
    }

    private func current() async -> Vocabulary {
        for await vocabulary in repository.vocabulary() { return vocabulary }
        return .empty
    }

    private func install(_ level: Int) async throws {
        let vocabulary = await current()
        try await repository.install(HSK.plan(level: level, words: words, topLevelFolders: vocabulary.folders(in: nil).count))
    }

    @Test("a fresh store has Starter, then HSK holding HSK 1's six decks, sharing words Starter has")
    func seeding() async {
        VocabularyStore.seedIfNeeded(container)
        let vocabulary = await current()

        #expect(vocabulary.folders(in: nil).map(\.name) == ["Starter", "HSK"])
        let hsk = vocabulary.folders.first { $0.builtInKey == HSK.rootKey }!
        #expect(vocabulary.folders(in: hsk.id).map(\.name) == ["HSK 1"])
        let level1 = vocabulary.folders.first { $0.builtInKey == HSK.levelKey(1) }!
        #expect(vocabulary.decks(in: level1.id).count == 6)
        #expect(vocabulary.words.filter { $0.hanzi == "你好" }.count == 1)
        #expect(vocabulary.words.count < 65 + 294)
    }

    @Test("a level's decks list in number order under the default sort, as Starter's do in plan order")
    func defaultOrder() async throws {
        VocabularyStore.seedIfNeeded(container)
        let vocabulary = await current()
        let level1 = vocabulary.folders.first { $0.builtInKey == HSK.levelKey(1) }!
        let starter = vocabulary.folders.first { $0.builtInKey == SampleVocabulary.builtInKey }!

        #expect(vocabulary.decks(in: level1.id, sortedBy: .default).map(\.name) == (1...6).map { HSK.deckName(1, $0) })
        #expect(vocabulary.decks(in: starter.id, sortedBy: .default).map(\.name)
            == SampleVocabulary.deckPlan.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test("installing again changes nothing")
    func idempotent() async throws {
        try await install(1)
        let once = await current()
        try await install(1)
        let twice = await current()

        #expect(twice.decks.map(\.id) == once.decks.map(\.id))
        #expect(twice.folders.map(\.id) == once.folders.map(\.id))
        #expect(twice.words.count == once.words.count)
    }

    @Test("a deleted deck, or a deleted level, comes back; a renamed one is left alone")
    func restoring() async throws {
        try await install(1)
        let decks = await current().decks
        let renamed = decks[0]
        try await repository.renameDeck(id: renamed.id, name: "My favourites")
        try await repository.deleteDeck(id: decks[1].id)

        try await install(1)
        var vocabulary = await current()
        #expect(vocabulary.decks.count == 6)
        #expect(vocabulary.deck(id: renamed.id)?.name == "My favourites")
        #expect(vocabulary.decks.filter { $0.builtInKey == HSK.deckKey(1, 2) }.count == 1)

        let hsk = vocabulary.folders.first { $0.builtInKey == HSK.rootKey }!
        try await repository.deleteFolder(id: hsk.id)
        try await install(1)
        vocabulary = await current()
        #expect(vocabulary.folders.compactMap(\.builtInKey).sorted() == [HSK.rootKey, HSK.levelKey(1)])
        #expect(vocabulary.decks.count == 6)
    }

    @Test("a second level goes beside the first inside the same HSK folder")
    func secondLevel() async throws {
        try await install(1)
        try await install(2)
        let vocabulary = await current()
        let hsk = vocabulary.folders.first { $0.builtInKey == HSK.rootKey }!

        #expect(vocabulary.folders.filter { $0.builtInKey == HSK.rootKey }.count == 1)
        #expect(vocabulary.folders(in: hsk.id).map(\.name) == ["HSK 1", "HSK 2"])
        #expect(vocabulary.decks.count == 10)
    }
}
