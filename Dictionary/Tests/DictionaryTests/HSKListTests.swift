import Foundation
import Testing
@testable import DictionaryDomain
@testable import DictionaryData

/// Against the bundled list, so a regenerated `HSK.tsv` that changes a level fails here.
@Suite("HSK list")
nonisolated struct HSKListTests {
    private let words = try! BundledHSK.words()

    @Test("each level has the 2025 revision's words, less the erhua ones it already has in standard form, plus second readings")
    func counts() {
        let counts = Dictionary(grouping: words, by: \.level).mapValues(\.count)
        // 294 and 487 in the syllabus. 哪儿, 这儿 and 那儿 are 哪里, 这里 and 那里, already in
        // HSK 1, and 一块儿 is 一起, already in HSK 2. readings.tsv adds 7, 5, 8, 11 and 11.
        #expect(counts == [1: 298, 2: 202, 3: 494, 4: 983, 5: 1558, 6: 1684, 7: 4876])
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
        // From the native speaker's review.
        ("牛", "niú", "cattle"), ("才", "cái", "only then, just"),
        ("最", "zuì", "(the) most ..."), ("同学", "tóngxué", "classmate"),
    ])
    func headlines(hanzi: String, pinyin: String, headline: String) {
        let word = words.first { $0.hanzi == hanzi }
        #expect(word?.pinyin == pinyin)
        #expect(word?.meanings.first == headline)
    }

    @Test("a word whose every meaning was chosen by hand has exactly those")
    func replacedSenses() {
        let zui = words.first { $0.hanzi == "最" }
        #expect(zui?.meanings == ["(the) most ...", "best or most extreme example"])
        #expect(zui?.replacesSenses == true)
        #expect(words.first { $0.hanzi == "在" }?.replacesSenses == false)
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
}
