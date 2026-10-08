import Foundation
import Testing
@testable import DictionaryDomain

@Suite("Choosing an example")
nonisolated struct ExamplePickingTests {
    private let easy = ExampleSentence(hanzi: "他是学生。", pinyin: "", english: "", words: ["他", "是", "学生"])
    private let known = ExampleSentence(hanzi: "我是学生。", pinyin: "", english: "", words: ["我", "是", "学生"])
    private let harder = ExampleSentence(hanzi: "我们都是学生。", pinyin: "", english: "", words: ["我们", "都", "是", "学生"])

    @Test("fewest unknown words wins, the word being taught never counts, and equals keep their order")
    func fewestUnknown() {
        let sentences = [easy, harder, known]
        #expect(sentences.best(teaching: "学生", knowing: ["我", "是"]) == known)
        #expect(sentences.best(teaching: "学生", knowing: []) == easy)
        #expect(sentences.best(teaching: "学生", knowing: ["我", "他", "是"]) == easy)
        #expect([ExampleSentence]().best(teaching: "学生", knowing: []) == nil)
    }
}
