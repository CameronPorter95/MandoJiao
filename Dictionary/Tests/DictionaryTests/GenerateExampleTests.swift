import Foundation
import Testing
@testable import DictionaryData
@testable import DictionaryDomain

@Suite("Writing an example on the device")
nonisolated struct GenerateExampleTests {
    /// Answers each attempt in turn, repeating the last.
    private actor ScriptedGenerator: ExampleGenerating {
        private let answers: [ExampleWriting]
        private(set) var requests: [ExampleRequest] = []

        init(_ answers: ExampleWriting...) {
            self.answers = answers
        }

        func example(for request: ExampleRequest) -> ExampleWriting {
            requests.append(request)
            return answers[min(requests.count, answers.count) - 1]
        }
    }

    private let hit = ExampleRequest(hanzi: "打", pinyin: "dǎ", meaning: "to hit, to strike", known: ["我", "你"])
    private let good = ExampleSentence(hanzi: "你别打我。", pinyin: "", english: "Don't hit me.")

    private func generated(_ hanzi: String, english: String = "Don't hit me.") async throws -> ExampleSentence? {
        let use = GenerateExampleUseCase(generator: ScriptedGenerator(.written(ExampleSentence(hanzi: hanzi, pinyin: "", english: english))))
        return try await use(hit)
    }

    @Test("a refusal or an unfit sentence is tried again, up to three times in all")
    func retries() async throws {
        let refusedOnce = ScriptedGenerator(.refused, .written(good))
        #expect(try await GenerateExampleUseCase(generator: refusedOnce)(hit) == good)
        let unfitTwice = ScriptedGenerator(.written(ExampleSentence(hanzi: "你别碰我。", pinyin: "", english: "Don't touch me.")), .refused, .written(good))
        #expect(try await GenerateExampleUseCase(generator: unfitTwice)(hit) == good)

        let neverFit = ScriptedGenerator(.refused)
        #expect(try await GenerateExampleUseCase(generator: neverFit)(hit) == nil)
        #expect(await neverFit.requests.count == GenerateExampleUseCase.attempts)
    }

    @Test("no model is not asked again")
    func unavailable() async throws {
        let generator = ScriptedGenerator(.unavailable, .written(good))
        #expect(try await GenerateExampleUseCase(generator: generator)(hit) == nil)
        #expect(await generator.requests.count == 1)
    }

    @Test("a short sentence in Hanzi that uses the word is kept")
    func kept() async throws {
        #expect(try await generated("你别打我。")?.hanzi == "你别打我。")
    }

    @Test("a sentence is dropped if it leaves the word out, has other scripts, runs long or has no translation", arguments: [
        ("你别碰我。", "Don't touch me."),
        ("Don't 打 me", "Don't hit me."),
        ("你别打我123", "Don't hit me."),
        ("我昨天在学校里看见他打了一个比我小很多的男孩子。", "Long."),
        ("你别打我。", " "),
    ])
    func dropped(hanzi: String, english: String) async throws {
        #expect(try await generated(hanzi, english: english) == nil)
    }

    @Test("nothing is asked of the model for a meaning with nothing to check")
    func grammar() async throws {
        let generator = ScriptedGenerator(.written(ExampleSentence(hanzi: "我吃了。", pinyin: "", english: "I ate.")))
        let request = ExampleRequest(hanzi: "了", pinyin: "le", meaning: "(completed action marker)", known: [])
        #expect(try await GenerateExampleUseCase(generator: generator)(request) == nil)
        #expect(await generator.requests.isEmpty)
    }

    @Test("the prompt asks for the sense, and for the learner's own words")
    func prompt() {
        let prompt = ModelExampleGenerator.prompt(for: hit)
        #expect(prompt.contains("打 (dǎ)"))
        #expect(prompt.contains("\"to hit, to strike\""))
        #expect(prompt.contains("你、我"))
    }

    @Test("a written sentence's pinyin takes the card's reading for the word and the lexicon's for the rest")
    func pinyin() async throws {
        let lexicon = Lexicon.repository
        #expect(try await SentencePinyin.spell("你别打我。", word: "打", wordPinyin: "dǎ", lexicon: lexicon) == "Nǐ bié dǎ wǒ.")
        let bank = try await SentencePinyin.spell("他在银行工作，我也是。", word: "银行", wordPinyin: "yínháng", lexicon: lexicon)
        #expect(bank == "Tā zài yínháng gōngzuò, wǒ yě shì.")
    }
}
