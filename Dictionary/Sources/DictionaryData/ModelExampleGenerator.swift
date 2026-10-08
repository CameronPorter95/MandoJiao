import DictionaryDomain
import Foundation
import FoundationModels

/// Writes an example sentence with Apple's on-device model, for a word none of Tatoeba's
/// sentences use in the card's sense. Unavailable on a device without the model, with Apple
/// Intelligence off, while the model is not ready, or where it does not write Chinese.
///
/// Only the Hanzi and the English are the model's. The pinyin is built from the card and the
/// lexicon, since a small model's pinyin cannot be trusted on polyphones.
actor ModelExampleGenerator: ExampleGenerating {
    private let lexicon: any LexiconRepository

    init(lexicon: any LexiconRepository) {
        self.lexicon = lexicon
    }

    func example(for request: ExampleRequest) async throws -> ExampleWriting {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(Locale(identifier: "zh-Hans")) else { return .unavailable }

        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let written: WrittenExample
        do {
            written = try await session.respond(to: Self.prompt(for: request), generating: WrittenExample.self, options: Self.options).content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .assetsUnavailable, .unsupportedLanguageOrLocale:
                return .unavailable
            // An answer that runs on past its limit, as one did on the Mac, is as unusable as a
            // refusal, and another try may be short.
            case .guardrailViolation, .refusal, .decodingFailure, .rateLimited, .concurrentRequests, .exceededContextWindowSize:
                return .refused
            default:
                throw error
            }
        }
        let hanzi = written.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        // Characters the lexicon cannot read have no pinyin to show, so this one is not usable;
        // another may be.
        guard let pinyin = try await SentencePinyin.spell(hanzi, word: request.hanzi, wordPinyin: request.pinyin, lexicon: lexicon) else {
            return .refused
        }
        return .written(ExampleSentence(hanzi: hanzi, pinyin: pinyin, english: written.english.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    static let instructions = """
        You write example sentences for someone learning Mandarin Chinese. Write natural, \
        everyday Mandarin in simplified Chinese characters only: no pinyin, no Latin letters, \
        no digits, and Chinese punctuation such as 。，？！. Keep each sentence short and simple, \
        the kind a beginner's textbook uses.
        """

    /// One short sentence and its translation need far less; uncapped, an answer on the Mac
    /// ran on until it filled the model's whole 4,096-token context.
    private static let options = GenerationOptions(maximumResponseTokens: 120)

    /// No list of the learner's words: asked to keep to the starter's, a native speaker judged
    /// 37% of its sentences natural and 27% wrong, many of them nonsense built around 买书 and
    /// 学校 ("go to the junior high school to buy books"); asked freely, 61% and 20%.
    static func prompt(for request: ExampleRequest) -> String {
        let reading = request.pinyin.isEmpty ? "" : " (\(request.pinyin))"
        // "Exactly as written": asked only to use 看病, it wrote 看医生 three times in three.
        return """
            Write one sentence that uses \(request.hanzi)\(reading) to mean "\(request.meaning)". \
            The sentence must contain \(request.hanzi) exactly as written, not a synonym. \
            Use it in that sense only. Keep the sentence under twelve characters.
            """
    }
}

@Generable
struct WrittenExample {
    @Guide(description: "One short sentence in simplified Chinese characters that uses the word in the given sense")
    var chinese: String
    @Guide(description: "A natural English translation of that sentence")
    var english: String
}

/// The one generator, for the app's lifetime.
public nonisolated enum OnDeviceExamples {
    /// Held by the owner on 2026-10-08 until a second native-speaker review: of the first
    /// round's sentences, 61% were natural at best, and many translations were wrong. While
    /// held the app writes nothing, so a card with no sentence in its sense shows no example,
    /// as on a phone without the model. The review harness uses `model` regardless.
    public static let isHeld = true

    public static let model: any ExampleGenerating = ModelExampleGenerator(lexicon: Lexicon.repository)

    public static var generator: any ExampleGenerating { isHeld ? HeldExampleGenerator() : model }
}

/// Writes nothing, as if there were no model.
nonisolated struct HeldExampleGenerator: ExampleGenerating {
    func example(for request: ExampleRequest) -> ExampleWriting { .unavailable }
}
