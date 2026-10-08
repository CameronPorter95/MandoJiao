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

        let hanzi: String
        let english: String
        do {
            let session = LanguageModelSession(model: model, instructions: Self.instructions)
            hanzi = try await session.respond(to: Self.prompt(for: request), generating: WrittenExample.self, options: Self.options)
                .content.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            // A fresh session for the English: in the second review a native speaker judged 78% of
            // these translations right against 71% of those written with the sentence, and the
            // separate one won 11 of the 16 where they differed.
            let translator = LanguageModelSession(model: model, instructions: Self.translatorInstructions)
            english = try await translator.respond(to: Self.translationPrompt(of: hanzi, for: request), options: Self.translationOptions)
                .content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LanguageModelSession.GenerationError {
            ExampleLog.failed(request, error)
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
        // Characters the lexicon cannot read have no pinyin to show, so this one is not usable;
        // another may be.
        guard let pinyin = try await SentencePinyin.spell(hanzi, word: request.hanzi, wordPinyin: request.pinyin, lexicon: lexicon) else {
            ExampleLog.wrote(request, hanzi: hanzi, english: english, verdict: "no pinyin")
            return .refused
        }
        let sentence = ExampleSentence(hanzi: hanzi, pinyin: pinyin, english: english)
        let fixed = ExampleSentence(hanzi: hanzi, pinyin: pinyin, english: EnglishWordOrder.speakerLast(english))
        ExampleLog.wrote(request, hanzi: hanzi, english: english, verdict: GenerateExampleUseCase.isFit(fixed, for: request) ? "fit" : "unfit")
        return .written(sentence)
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
        // "Complete sentence": asked for "one sentence", it gave phrases such as 小明和小红.
        return """
            Write one complete sentence, with a subject and a verb, that uses \(request.hanzi)\(reading) \
            to mean "\(request.meaning)". The sentence must contain \(request.hanzi) exactly as \
            written, not a synonym. Use it in that sense only. Keep the sentence under twelve \
            characters.
            """
    }

    /// No word-order rule in here; `EnglishWordOrder` makes it. Given "my mom and I" as an
    /// example, it translated 家人在一起玩耍, the family playing together, as "My mom and I are
    /// having fun together"; given the rule as the pattern "X and I", it wrote "X and I went to
    /// the park with my mom".
    static let translatorInstructions = """
        You translate Mandarin Chinese into English for a learner. Write what a native English \
        speaker would say to mean the same thing, not a word-for-word gloss of the Chinese. \
        Translate only what the sentence says, adding nothing, and keep its tense and its \
        words' precise meanings.
        """

    /// Told what the word means, since both translations in the first trial made 后年, the year
    /// after next, "next year".
    static func translationPrompt(of hanzi: String, for request: ExampleRequest) -> String {
        """
        In this sentence, \(request.hanzi) means "\(request.meaning)". Translate the sentence \
        into English. Reply with the translation only.
        \(hanzi)
        """
    }

    private static let translationOptions = GenerationOptions(maximumResponseTokens: 80)
}

/// Only `chinese` is used. The English written alongside it glossed the Chinese word order, "I
/// and my mom went to the supermarket", and a native speaker judged fewer of those right than
/// of translations asked for on their own. It stays because without it, on the Mac, every
/// request for 和 and 女生 tripped the guardrail; with it, they were written.
@Generable
struct WrittenExample {
    @Guide(description: "One short sentence in simplified Chinese characters that uses the word in the given sense")
    var chinese: String
    @Guide(description: "What a native English speaker would say to mean the same thing: natural English in English word order, not a word-for-word gloss of the Chinese")
    var english: String
}

/// The one generator, for the app's lifetime.
public nonisolated enum OnDeviceExamples {
    /// Held by the owner on 2026-10-08 until a second native-speaker review: of the first
    /// round's sentences, 61% were natural at best, and many translations were wrong. In the
    /// second, 81% were natural and 70% were natural with a right translation, and the owner
    /// lifted the hold on 2026-10-09, with written sentences marked as AI-generated. While held
    /// the app writes nothing, so a card with no sentence in its sense shows no example, as on
    /// a phone without the model. The review harness uses `model` regardless.
    public static let isHeld = false

    public static let model: any ExampleGenerating = ModelExampleGenerator(lexicon: Lexicon.repository)

    public static var generator: any ExampleGenerating { isHeld ? HeldExampleGenerator() : model }
}

/// Writes nothing, as if there were no model.
nonisolated struct HeldExampleGenerator: ExampleGenerating {
    func example(for request: ExampleRequest) -> ExampleWriting { .unavailable }
}
