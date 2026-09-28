import Foundation
import Testing
@testable import VocabularyDomain
@testable import VocabularyData

/// Against the bundled dictionary, so a regenerated `Dictionary.tsv` that loses a reading or a
/// sense fails here.
@Suite("Dictionary")
nonisolated struct DictionaryTests {
    private let dictionary = DictionaryRepositoryImpl()

    @Test("a character keeps every reading, the preferred one first, each with all its senses")
    func readings() async throws {
        let xing = try await dictionary.entries(forHanzi: "行")
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

    @Test("search finds a headword by English, a whole gloss before a gloss merely holding the word")
    func searchByEnglish() async throws {
        #expect(try await dictionary.search("cat", limit: 5).first?.simplified == "猫")
        #expect(try await dictionary.search("computer", limit: 5).first?.simplified == "电脑")
        #expect(try await dictionary.search("bank", limit: 10).contains { $0.simplified == "银行" })
        #expect(try await dictionary.search("drink", limit: 5).contains { $0.simplified == "喝" })
    }

    /// CC-CEDICT has no frequency, so the commoner of two exact matches can lose. Pinned so a
    /// better ranking, say from HSK's frequency order, shows up here.
    @Test("search ranks by a stand-in for frequency, and it puts 合 before 和 and 于 before 去")
    func searchRankingCost() async throws {
        let he = try await dictionary.search("he", limit: 5).map(\.simplified)
        #expect(he.firstIndex(of: "合")! < he.firstIndex(of: "和")!)
        #expect(try await dictionary.search("go", limit: 2).map(\.simplified) == ["于", "去"])
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
