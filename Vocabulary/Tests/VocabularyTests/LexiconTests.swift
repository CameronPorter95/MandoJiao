import Foundation
import Testing
import CoreDomain
@testable import VocabularyDomain
@testable import VocabularyData

/// Against the bundled lexicon, so a regenerated `Lexicon.tsv` that changes a reading fails here.
@Suite("Lexicon")
nonisolated struct LexiconTests {
    private static let lexicon = LexiconRepositoryImpl(source: BundledLexiconSource())

    private func suggest(_ hanzi: String) async throws -> WordSuggestion? {
        try await Self.lexicon.suggestion(forHanzi: hanzi)
    }

    @Test("a headword gets its dictionary reading and first sense")
    func headwords() async throws {
        #expect(try await suggest("喝") == WordSuggestion(hanzi: "喝", pinyin: "hē", english: "to drink"))
        #expect(try await suggest("银行") == WordSuggestion(hanzi: "银行", pinyin: "yínháng", english: "bank"))
        #expect(try await suggest("绿")?.pinyin == "lǜ")
        #expect(try await suggest("西安")?.pinyin == "Xī'ān")
    }

    @Test("a lone character gets its everyday reading, not the dictionary's first", arguments: [
        ("行", "xíng"), ("了", "le"), ("都", "dōu"), ("还", "hái"), ("着", "zhe"), ("重", "zhòng"),
        ("吗", "ma"), ("呢", "ne"), ("没", "méi"), ("看", "kàn"), ("要", "yào"), ("说", "shuō"),
    ])
    func everydayReading(hanzi: String, pinyin: String) async throws {
        #expect(try await suggest(hanzi)?.pinyin == pinyin)
    }

    @Test("cost: some lone characters get a real but less common reading", arguments: [
        ("长", "zhǎng", "cháng"), ("得", "dé", "de"), ("教", "jiào", "jiāo"),
    ])
    func lessCommonReading(hanzi: String, suggested: String, everyday: String) async throws {
        let pinyin = try await suggest(hanzi)?.pinyin
        #expect(pinyin == suggested)
        #expect(pinyin != everyday)
    }

    @Test("a cross reference takes the English of the word it points at")
    func crossReference() async throws {
        #expect(try await suggest("一点儿")?.english == "a bit, a little bit")
        #expect(try await suggest("西安")?.english == "Xi'an")
    }

    @Test("a phrase the lexicon lacks gets pinyin from its longest pieces and no English")
    func phrase() async throws {
        #expect(try await suggest("我喝茶") == WordSuggestion(hanzi: "我喝茶", pinyin: "wǒ hēchá", english: ""))
        #expect(try await suggest("我想喝茶")?.pinyin == "wǒ xiǎng hēchá")
    }

    @Test("text that is not all Hanzi suggests nothing")
    func notHanzi() async throws {
        #expect(try await suggest("he") == nil)
        #expect(try await suggest("喝x") == nil)
    }

    @Test("cost: every starter word's pinyin matches, except 对不起's written tone on 不")
    func starterWords() async throws {
        let comparable = { (pinyin: String) in
            pinyin.lowercased().filter { $0 != " " && $0 != "'" }
        }
        var disagreements: [String] = []
        for entry in SampleVocabulary.deckPlan.flatMap(\.entries) {
            let suggested = try await suggest(entry.hanzi)?.pinyin ?? ""
            if comparable(suggested) != comparable(entry.pinyin) { disagreements.append(entry.hanzi) }
        }
        #expect(disagreements == ["对不起"])
    }
}

@Suite("Lexicon repository")
nonisolated struct LexiconRepositoryTests {
    private actor StubSource: LexiconSource {
        private(set) var loads = 0
        private var results: [Result<[String: WordSuggestion], any Error>]

        init(_ results: [Result<[String: WordSuggestion], any Error>]) {
            self.results = results
        }

        func entries() throws -> [String: WordSuggestion] {
            loads += 1
            return try results.removeFirst().get()
        }
    }

    private static let water = ["水": WordSuggestion(hanzi: "水", pinyin: "shuǐ", english: "water")]

    @Test("a source failure is unexpected, and the next lookup loads again")
    func failure() async throws {
        let source = StubSource([.failure(LexiconSourceError.missingResource), .success(Self.water)])
        let lexicon = LexiconRepositoryImpl(source: source)

        await #expect {
            try await lexicon.suggestion(forHanzi: "水")
        } throws: { error in
            guard case .unexpected = error as? VocabularyDomainError else { return false }
            return true
        }
        #expect(try await lexicon.suggestion(forHanzi: "水")?.english == "water")
        #expect(await source.loads == 2)
    }

    @Test("cancellation propagates as cancellation")
    func cancellation() async {
        let lexicon = LexiconRepositoryImpl(source: StubSource([.failure(CancellationError())]))
        await #expect(throws: CancellationError.self) {
            try await lexicon.suggestion(forHanzi: "水")
        }
    }

    @Test("the source is read once for every lookup after it")
    func loadsOnce() async throws {
        let source = StubSource([.success(Self.water)])
        let lexicon = LexiconRepositoryImpl(source: source)
        _ = try await lexicon.suggestion(forHanzi: "水")
        _ = try await lexicon.suggestion(forHanzi: "水水")
        #expect(await source.loads == 1)
    }
}
