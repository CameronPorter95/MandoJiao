import Foundation
import Testing
@testable import VocabularyDomain
@testable import VocabularyData

/// Against the bundled dictionary, so a regenerated `Dictionary.tsv` that loses a reading or a
/// sense fails here.
@Suite("Dictionary")
nonisolated struct DictionaryTests {
    private let dictionary = DictionaryRepositoryImpl()

    /// CC-CEDICT as bundled, before HSK's headlines are put first.
    private func raw(_ hanzi: String) async throws -> [DictionaryEntry] {
        try await BundledDictionary.shared.index().entries(forHanzi: hanzi)
    }

    @Test("a character keeps every reading, the preferred one first, each with all its senses")
    func readings() async throws {
        let xing = try await raw("行")
        #expect(xing.map(\.pinyin) == ["xíng", "háng", "héng"])
        #expect(xing.first?.isPreferred == true)
        #expect(xing.first?.senses.contains("behavior, conduct") == true)
        #expect(xing.first?.senses.count == 9)

        let le = try await dictionary.entries(forHanzi: "了")
        #expect(le.first?.pinyin == "le")
        #expect(le.first?.senses.first == "(completed action marker)")
        #expect(le.contains { $0.pinyin == "liǎo" && $0.senses.first == "to finish" })
    }

    @Test("asides that say how a sense is used are kept, and ones that only point elsewhere are not")
    func asides() async throws {
        let ta = try await dictionary.entries(forHanzi: "他")
        #expect(ta.first?.senses.first == "(third-person singular) (since the early 20th century, usu. male) he, him, his")
        #expect(try await dictionary.entries(forHanzi: "西安").first?.senses == ["Xi'an, sub-provincial city and capital of Shaanxi Province"])
        #expect(try await dictionary.entries(forHanzi: "不在").isEmpty == false)
        #expect(try await dictionary.entries(forHanzi: "not a word").isEmpty)
    }

    @Test("a measure word, a sense beginning \"surname\" that is not a name, and an abbreviation keep their meaning")
    func sensesThatLookLikeReferences() async throws {
        #expect(try await dictionary.entries(forHanzi: "辆").first?.senses == ["classifier for vehicles"])
        #expect(try await dictionary.entries(forHanzi: "姓名").first?.senses == ["surname and given name, full name"])
        #expect(try await dictionary.entries(forHanzi: "湘").first?.senses.first == "Hunan province in south central China")
        #expect(try await dictionary.entries(forHanzi: "欧盟").first?.senses == ["European Union", "EU"])
        // A bare surname still points nowhere worth keeping.
        #expect(try await dictionary.entries(forHanzi: "于").first { $0.pinyin == "Yú" }?.senses == [])
    }

    @Test("of two lines in one reading, a rare traditional form loses", arguments: [
        ("年", "year"), ("冬", "winter"), ("云", "cloud"),
        // 裡 and 里 are both common, so "inside" stays ahead of the unit of length.
        ("里", "lining"),
    ])
    func rareForms(hanzi: String, headline: String) async throws {
        #expect(try await raw(hanzi).first?.senses.first == headline)
    }

    @Test("a reading CC-CEDICT gives several lines is one entry, its senses once each, its traditional forms together")
    func readingsMerged() async throws {
        let jiu = try await raw("韭")
        #expect(jiu.map(\.pinyin) == ["jiǔ"])
        #expect(jiu.first?.senses == ["leek"])
        #expect(jiu.first?.traditional == "韭, 韮")
        let zhou = try #require(try await raw("周").first { $0.pinyin == "zhōu" })
        #expect(zhou.senses.contains("to make a circuit") && zhou.senses.contains("week"))
        let wei = try await raw("为")
        #expect(Set(wei.map(\.pinyin)) == ["wéi", "wèi"] && wei.count == 2)
        // 爲 wéi, "variant of 為|为[wei2]", takes wéi's senses, not the preferred wèi's.
        #expect(wei.first { $0.pinyin == "wéi" }?.senses.contains("because of") == false)
        #expect(wei.first { $0.pinyin == "wéi" }?.traditional == "為, 爲")
        // A reference names a reading's case too: 㥁, "variant of 德[de2]", is "virtue", not Germany.
        #expect(try await raw("㥁").first?.senses.first == "virtue")
    }

    @Test("an HSK word's headline is the first meaning of its reading, and nothing repeats it")
    func headlinesInTheDictionary() async throws {
        let zai = try await dictionary.entries(forHanzi: "在")
        #expect(zai.first?.senses.prefix(2) == ["at, in", "to exist, to be alive"])
        // 里's lǐ is one reading of 裡, 裏 and 里, headed by "inside", with the unit of length after.
        let li = try #require(try await dictionary.entries(forHanzi: "里").first { $0.pinyin == "lǐ" })
        #expect(li.senses.first == "inside")
        #expect(li.senses.contains("li, ancient measure of length, approx. 500 m"))
        // 离's headline says two of its senses, so neither is listed again.
        let leave = try await dictionary.entries(forHanzi: "离").first { $0.pinyin == "lí" }
        #expect(leave?.senses.first == "to leave; (in giving distances) from")
        #expect(leave?.senses.contains("to leave") == false)
        #expect(leave?.senses.contains("(in giving distances) from") == false)
        // "to" is a part of none of "to give"'s parts, so it stays.
        #expect(try await dictionary.entries(forHanzi: "给").first?.senses.prefix(2) == ["to give", "to"])
        // Each of a character's HSK readings heads its own line.
        let chang = try await dictionary.entries(forHanzi: "长")
        #expect(chang.first { $0.pinyin == "cháng" }?.senses.first == "long")
        #expect(chang.first { $0.pinyin == "zhǎng" }?.senses.first == "to grow")
        #expect(try await dictionary.search("bullet", limit: 1).first?.pinyin == "dàn")
        // Meanings chosen in full replace the reading's senses outright.
        #expect(try await dictionary.entries(forHanzi: "最").first?.senses == ["(the) most ...", "best or most extreme example"])
        // Only the reading HSK means: 告诉's gàosù is still "to press charges".
        #expect(try await dictionary.entries(forHanzi: "告诉").first { $0.pinyin == "gàosù" }?.senses.first
            == "to press charges, to file a complaint")
    }

    @Test("no sense in the whole dictionary keeps a Hanzi or a bracketed pinyin reference")
    func noReferences() async throws {
        let index = try await BundledDictionary.shared.index()
        let offending = index.lines.keys.flatMap { index.entries(forHanzi: $0) }.flatMap(\.senses).filter { sense in
            sense.contains("[") || sense.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
        }
        #expect(offending.isEmpty, "\(offending.prefix(5))")
        #expect(index.lines.count == 121_351)
    }

    @Test("search finds a headword by Hanzi, either form, and by pinyin with or without tones")
    func searchByHanziAndPinyin() async throws {
        for query in ["银行", "銀行", "yínháng", "yin2hang2", "Yin hang"] {
            #expect(try await dictionary.search(query, limit: 5).first?.simplified == "银行", "\(query)")
        }
        #expect(try await dictionary.search("银", limit: 5).first?.simplified == "银")
        #expect(try await dictionary.search("银", limit: 20).allSatisfy { $0.simplified.contains("银") })
    }

    @Test("search by pinyin finds every tone without one, and only the tone written with one")
    func searchByTone() async throws {
        let toneless = try await dictionary.search("wei", limit: 200).map(\.pinyin)
        #expect(Set(["wéi", "wèi", "wěi", "wēi"]).isSubset(of: toneless))
        for (query, tone) in [("wéi", "wéi"), ("wei2", "wéi"), ("wèi", "wèi"), ("wei4", "wèi")] {
            let results = try await dictionary.search(query, limit: 200)
            #expect(!results.isEmpty && results.allSatisfy { $0.pinyin.lowercased().hasPrefix(tone) }, "\(query)")
        }
        #expect(try await dictionary.search("wéi", limit: 20).contains { $0.simplified == "为" })
        #expect(try await dictionary.search("wèi", limit: 20).contains { $0.simplified == "为" })
    }

    @Test("search finds a headword by English, a whole gloss before a gloss merely holding the word")
    func searchByEnglish() async throws {
        #expect(try await dictionary.search("cat", limit: 5).first?.simplified == "猫")
        #expect(try await dictionary.search("computer", limit: 5).first?.simplified == "电脑")
        #expect(try await dictionary.search("bank", limit: 10).contains { $0.simplified == "银行" })
        #expect(try await dictionary.search("drink", limit: 5).contains { $0.simplified == "喝" })
    }

    /// CC-CEDICT has no frequency, so HSK's ranks it: an exact match on one of a word's first
    /// senses, then HSK words by frequency.
    @Test("search puts the everyday word first", arguments: [
        ("bank", "银行"), ("go", "去"), ("drink", "喝"), ("eat", "吃"), ("you", "你"),
        ("thank you", "谢谢"), ("year", "年"), ("money", "钱"), ("tell", "告诉"), ("he", "他"),
    ])
    func searchRanking(query: String, first: String) async throws {
        #expect(try await dictionary.search(query, limit: 1).first?.simplified == first)
    }

    /// No CC-CEDICT sense of 在 is "at" or "in" on its own; its HSK headline, chosen by hand,
    /// is, and search matches that as its first sense.
    @Test("search finds a word by its HSK headline where CC-CEDICT lacks the sense", arguments: [
        ("at", "在"), ("in", "在"), ("to wear", "穿"),
    ])
    func searchByHeadline(query: String, first: String) async throws {
        #expect(try await dictionary.search(query, limit: 1).first?.simplified == first)
    }

    @Test("a result shows its HSK headline, and a word HSK lacks its first sense, made short")
    func resultSummary() async throws {
        let zai = try await dictionary.search("在", limit: 1).first
        #expect(zai?.headline == "at, in")
        #expect(zai?.summary == "at, in")
        #expect(zai?.entry.senses.first == "to exist, to be alive")
        let yinhang = try await dictionary.search("banker", limit: 5).first { $0.simplified == "银行家" }
        #expect(yinhang?.headline == nil)
        #expect(yinhang?.summary == "banker")
    }

    @Test("search lists a headword once per reading, and nothing for a blank query")
    func searchDuplicates() async throws {
        let results = try await dictionary.search("go", limit: 100)
        #expect(Set(results.map { "\($0.simplified) \($0.pinyin)" }).count == results.count)
        #expect(try await SearchDictionaryUseCase(repository: dictionary)("  ").isEmpty)
        #expect(try await dictionary.search("zzzzqqq", limit: 5).isEmpty)
    }

    @Test("a sense is made short for a tile: asides dropped, unless it is only an aside")
    func plain() {
        #expect(Gloss.plain("(third-person singular) (since the early 20th century, usu. male) he, him, his") == "he, him, his")
        #expect(Gloss.plain("(completed action marker)") == "completed action marker")
        #expect(Gloss.plain("(bound form) row, line") == "row, line")
        #expect(Gloss.plain("Beijing municipality, capital of the People's Republic of China") == "Beijing municipality")
    }
}
