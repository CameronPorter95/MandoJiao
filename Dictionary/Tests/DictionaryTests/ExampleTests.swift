import Foundation
import Testing
@testable import DictionaryData
@testable import DictionaryDomain

/// Against the bundled sentences, so a regenerated `Examples.tsv` that attaches a sentence
/// to the wrong reading fails here.
@Suite("Example sentences")
nonisolated struct ExampleTests {
    private let examples = FindExamplesUseCase(repository: ExampleRepositoryImpl())

    @Test("a word's examples say its reading, not another the same characters have")
    func readings() async throws {
        let long = try await examples(hanzi: "长", pinyin: "cháng")
        let grow = try await examples(hanzi: "长", pinyin: "zhǎng")
        #expect(!long.isEmpty && !grow.isEmpty)
        // Lowercased, as a sentence can begin with the word: "Zhǎng bù gāo bù shì huàishì."
        #expect(long.allSatisfy { $0.pinyin.lowercased().contains("cháng") })
        #expect(grow.allSatisfy { $0.pinyin.lowercased().contains("zhǎng") })
        #expect(Set(long).isDisjoint(with: grow))
    }

    @Test("a one-syllable word's tone tells its readings apart: liǎo's sentences are not le's or liào's")
    func toneOfOneSyllable() async throws {
        let liao = try await examples(hanzi: "了", pinyin: "liǎo")
        #expect(!liao.isEmpty)
        #expect(liao.allSatisfy { $0.pinyin.contains("liǎo") })
        #expect(try await examples(hanzi: "了", pinyin: "liào").allSatisfy { $0.pinyin.contains("liào") })
    }

    /// The sentences say dōngxi, things, with a neutral second syllable; the reading said tone
    /// for tone takes them.
    @Test("cost: east and west, dōngxī, has none of thing's sentences")
    func exactReadingWins() async throws {
        #expect(try await !examples(hanzi: "东西", pinyin: "dōngxi").isEmpty)
        #expect(try await examples(hanzi: "东西", pinyin: "dōngxī").isEmpty)
    }

    @Test("pinyin in any spelling finds the reading, and none finds the first")
    func spellings() async throws {
        let marked = try await examples(hanzi: "学生", pinyin: "xuésheng")
        #expect(!marked.isEmpty)
        #expect(try await examples(hanzi: "学生", pinyin: "xue2 sheng5") == marked)
        #expect(try await examples(hanzi: "学生", pinyin: "") == marked)
        #expect(try await examples(hanzi: " ", pinyin: "").isEmpty)
    }

    @Test("each sentence carries its words, which put back together are its characters")
    func words() async throws {
        let sentences = try await examples(hanzi: "朋友", pinyin: "péngyou")
        #expect(sentences.count > 3)
        for sentence in sentences {
            #expect(sentence.words.contains("朋友"), "\(sentence.hanzi)")
            #expect(sentence.words.joined() == sentence.hanzi.filter { !$0.isPunctuation && !$0.isWhitespace }, "\(sentence.hanzi)")
        }
    }

    @Test("the learner gets the sentence they know most words of, and the fewest words when they know none")
    func knownWords() async throws {
        let sentences = try await examples(hanzi: "朋友", pinyin: "péngyou")
        let shortest = sentences.map(\.words.count).min()
        #expect(sentences.best(teaching: "朋友", knowing: [])?.words.count == shortest)
        let known: Set<String> = ["我", "你", "他", "是", "的", "好", "有", "很", "了", "吗", "这", "我们", "在"]
        let unknown = { (sentence: ExampleSentence) in sentence.words.count { $0 != "朋友" && !known.contains($0) } }
        let chosen = try #require(sentences.best(teaching: "朋友", knowing: known))
        #expect(unknown(chosen) == sentences.map(unknown).min())
    }

    @Test("every HSK 1 word with an example has one short enough for a card, in simplified characters")
    func shortAndSimplified() async throws {
        let words = try BundledHSK.words().filter { $0.level == 1 }
        var found = 0
        for word in words {
            let sentences = try await examples(hanzi: word.hanzi, pinyin: word.pinyin)
            guard let first = sentences.first else { continue }
            found += 1
            #expect(first.hanzi.filter { $0.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) } }.count <= 16)
            #expect(!first.hanzi.contains("們") && !first.hanzi.contains("這"), "\(first.hanzi)")
            #expect(!first.english.isEmpty)
        }
        // 290 of HSK 1's 298 readings when the file was built.
        #expect(found >= 285)
    }
}
