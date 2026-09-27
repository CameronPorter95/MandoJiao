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

    @Test("a sense is made short for a tile: asides dropped, unless it is only an aside")
    func plain() {
        #expect(Gloss.plain("(third-person singular) (since the early 20th century, usu. male) he, him, his") == "he, him, his")
        #expect(Gloss.plain("(completed action marker)") == "completed action marker")
        #expect(Gloss.plain("(bound form) row, line") == "row, line")
        #expect(Gloss.plain("Beijing municipality, capital of the People's Republic of China") == "Beijing municipality")
    }
}
