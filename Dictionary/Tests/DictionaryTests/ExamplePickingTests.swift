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

    private let calling = ExampleSentence(hanzi: "我打你。", pinyin: "", english: "I'll call you.", words: ["我", "打", "你"])
    private let fighting = ExampleSentence(hanzi: "他们在打架。", pinyin: "", english: "They are fighting.", words: ["他们", "在", "打架"])
    private let hitting = ExampleSentence(hanzi: "他为什么打我？", pinyin: "", english: "Why did he hit me?", words: ["他", "为什么", "打", "我"])

    @Test("a sentence in the headline's sense comes first, then another meaning's, before any fit to the learner")
    func meaningFirst() {
        let sentences = [calling, fighting, hitting]
        let meanings = ["to hit, to strike", "to fight"]
        #expect(sentences.best(teaching: "打", meanings: meanings, knowing: ["我", "你"]) == hitting)
        #expect([calling, fighting].best(teaching: "打", meanings: meanings, knowing: []) == fighting)
    }

    @Test("none in any of the card's senses is none, for the model to write one")
    func noneInSense() {
        #expect([calling].best(teaching: "打", meanings: ["to hit, to strike"], knowing: ["我", "你"]) == nil)
    }

    @Test("a grammatical word has no sense to check, so the learner's fit decides")
    func grammarWord() {
        let le = ExampleSentence(hanzi: "我吃了。", pinyin: "", english: "I ate.", words: ["我", "吃", "了"])
        #expect([le].best(teaching: "了", meanings: ["(completed action marker)"], knowing: []) == le)
    }
}
