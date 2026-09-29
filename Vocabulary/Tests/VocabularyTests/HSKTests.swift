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

    @Test("each level has the 2025 revision's words, less the erhua ones it already has in standard form, plus second readings")
    func counts() {
        let counts = Dictionary(grouping: words, by: \.level).mapValues(\.count)
        // 294 and 487 in the syllabus. 哪儿, 这儿 and 那儿 are 哪里, 这里 and 那里, already in
        // HSK 1, and 一块儿 is 一起, already in HSK 2. readings.tsv adds 7, 5, 8 and 11.
        #expect(counts == [1: 298, 2: 202, 3: 494, 4: 983, 5: 1547, 6: 1684, 7: 4876])
        #expect(words.allSatisfy { !$0.pinyin.isEmpty && !$0.meanings.isEmpty && $0.meanings.count <= 4 })
        #expect(Set(words.map { "\($0.hanzi) \($0.pinyin)" }).count == words.count)
    }

    @Test("words are standard Mandarin, not Beijing erhua, and a real 儿 is kept")
    func erhua() {
        let hanzi = Set(words.map(\.hanzi))
        for standard in ["一点", "一会", "好玩", "面条", "聊天", "模特", "没法", "小偷", "哪里", "这里", "那里", "一起"] {
            #expect(hanzi.contains(standard), "\(standard)")
        }
        for erhua in ["一点儿", "一会儿", "哪儿", "这儿", "那儿", "一块儿", "没法儿", "小偷儿"] {
            #expect(!hanzi.contains(erhua), "\(erhua)")
        }
        #expect(hanzi.isSuperset(of: ["儿子", "女儿", "儿童"]))
        #expect(!words.contains { $0.pinyin.contains("r5") })
        #expect(words.first { $0.hanzi == "一点" }?.pinyin == "yīdiǎn")
    }

    @Test("a word takes the dictionary's senses for its reading, as written, at most four")
    func meanings() {
        let word = { (hanzi: String) in words.first { $0.hanzi == hanzi } }
        #expect(word("的")?.meanings.first == "of, ~'s (possessive particle)")
        // Not the archaic 秊's "grain", which the dictionary once preferred.
        #expect(word("年")?.meanings == ["year"])
        #expect(word("打")?.meanings.count == 4)
        // Its only sense, which the dictionary once dropped as a reference.
        #expect(word("辆")?.meanings == ["classifier for vehicles"])
        #expect(!words.contains { $0.meanings.contains { $0.contains("[") || $0.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) } } })
    }

    /// CC-CEDICT orders senses roughly by history, so for common words headlines.tsv picks the
    /// one a learner means, and sometimes the reading too.
    @Test("a common word heads with its everyday meaning, in its everyday reading", arguments: [
        ("在", "zài", "at, in"), ("穿", "chuān", "to wear, to put on (clothes, shoes etc.)"), ("钱", "qián", "money"),
        ("告诉", "gàosu", "to tell, to inform, to let know"), ("长", "cháng", "long"), ("妻子", "qīzi", "wife"),
        ("周", "zhōu", "week"), ("故事", "gùshi", "narrative, story, tale"),
        // From the native speaker's review, both meanings being common in the last.
        ("牛", "niú", "cattle"), ("才", "cái", "only then, just; ability, talent"),
    ])
    func headlines(hanzi: String, pinyin: String, headline: String) {
        let word = words.first { $0.hanzi == hanzi }
        #expect(word?.pinyin == pinyin)
        #expect(word?.meanings.first == headline)
    }

    @Test("the source's spellings of a reading are matched to the dictionary's", arguments: [
        ("略", "lüè"), ("闺女", "guīnü"), ("欧洲", "Ōuzhōu"), ("泄露", "xièlòu"),
        // The dictionary's ya has no senses, so the source's stands rather than yā, "ah".
        ("呀", "ya"),
    ])
    func sourceSpellings(hanzi: String, pinyin: String) {
        #expect(words.first { $0.hanzi == hanzi }?.pinyin == pinyin)
    }

    @Test("a character's other everyday readings are words of their own, beside its main one", arguments: [
        ("长", "cháng", "zhǎng", "to grow"), ("弹", "tán", "dàn", "bullet"), ("得", "dé", "děi", "to have to, must"),
        ("行", "xíng", "háng", "row, line; trade, business"), ("只", "zhǐ", "zhī", "classifier for birds and certain animals, one of a pair, some utensils, vessels etc"),
    ])
    func secondReadings(hanzi: String, main: String, second: String, headline: String) throws {
        let readings = words.filter { $0.hanzi == hanzi }
        #expect(readings.first?.pinyin == main)
        let other = try #require(readings.first { $0.pinyin == second })
        #expect(other.meanings.first == headline)
        #expect(other.level == readings.first?.level && other.rank == readings.first?.rank)
        // 教 was jiào until headlines.tsv made it the jiāo HSK 2 means.
        #expect(words.first { $0.hanzi == "教" }?.pinyin == "jiāo")
    }

    @Test("every installed word is found by its pinyin with tones, without them, and by tone numbers")
    func searchablePinyin() {
        let numbered = { (pinyin: String) in
            pinyin.decomposedStringWithCanonicalMapping.unicodeScalars.map { scalar -> String in
                switch scalar.value {
                case 0x304: "1"
                case 0x301: "2"
                case 0x30C: "3"
                case 0x300: "4"
                default: String(scalar)
                }
            }.joined()
        }
        let missed = words.filter { hsk in
            let word = Word(meanings: hsk.meanings, hanzi: hsk.hanzi, pinyin: hsk.pinyin)
            return ![hsk.pinyin, SearchQuery.toneless(hsk.pinyin), numbered(hsk.pinyin)].allSatisfy(word.matches)
        }
        #expect(missed.isEmpty, "\(missed.prefix(5).map(\.pinyin))")
    }

    @Test("a level splits evenly into decks of at most 50, most common words first")
    func plan() throws {
        let hsk1 = HSK.plan(level: 1, words: words, topLevelFolders: 1)
        #expect(hsk1.decks.map(\.words.count) == [50, 50, 50, 50, 49, 49])
        #expect(hsk1.decks.map(\.name).prefix(2) == ["HSK 1 · 1", "HSK 1 · 2"])
        #expect(hsk1.decks.first?.words.first?.hanzi == "的")
        #expect(hsk1.decks.map(\.key).last == "hsk/1/6")
        #expect(hsk1.folders.map(\.key) == ["hsk", "hsk/1"])

        #expect(HSK.plan(level: 2, words: words, topLevelFolders: 1).decks.map(\.words.count) == [41, 41, 40, 40, 40])
        // A second reading follows its main one into the same deck.
        let deck = try #require(HSK.plan(level: 4, words: words, topLevelFolders: 1).decks.first { $0.words.contains { $0.hanzi == "弹" } })
        #expect(deck.words.filter { $0.hanzi == "弹" }.map(\.pinyin) == ["tán", "dàn"])
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
        #expect(vocabulary.words.count < 65 + 291)
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

    @Test("an installed word keeps every meaning, and a word already in the library keeps its own")
    func installedMeanings() async throws {
        VocabularyStore.seedIfNeeded(container)
        let vocabulary = await current()
        let de = vocabulary.words.first { $0.hanzi == "的" }
        #expect(de?.meanings == words.first { $0.hanzi == "的" }?.meanings)
        #expect((de?.meanings.count ?? 0) > 1)
        let starter = SampleVocabulary.deckPlan.flatMap(\.entries).first { $0.hanzi == "你好" }
        #expect(vocabulary.words.first { $0.hanzi == "你好" }?.meanings == starter.map { [$0.english] })
    }

    @Test("a character's readings install as separate words, and one already in the library keeps its own meanings")
    func readingsInstall() async throws {
        // Saved by the user as dàn, and a 长 with no pinyin at all.
        container.mainContext.insert(VocabWord(meanings: ["a bomb"], hanzi: "弹", pinyin: "dàn"))
        container.mainContext.insert(VocabWord(meanings: ["long, my own"], hanzi: "长"))
        try container.mainContext.save()
        try await install(4)
        try await install(2)
        let vocabulary = await current()

        let tan = vocabulary.words.filter { $0.hanzi == "弹" }
        #expect(tan.count == 2)
        #expect(tan.first { $0.pinyin == "dàn" }?.meanings == ["a bomb"])
        #expect(tan.first { $0.pinyin == "tán" }?.english == "to play (a string instrument)")
        // The pinyin-less 长 is taken for the main reading, cháng; zhǎng is added beside it.
        let chang = vocabulary.words.filter { $0.hanzi == "长" }
        #expect(chang.count == 2)
        #expect(chang.contains { $0.meanings == ["long, my own"] })
        #expect(chang.contains { $0.pinyin == "zhǎng" })
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
        #expect(vocabulary.decks.count == 11)
    }
}
