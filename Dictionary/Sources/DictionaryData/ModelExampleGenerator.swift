import DictionaryDomain
import Foundation
import FoundationModels

/// Writes an example sentence with Apple's on-device model, for a word none of Tatoeba's
/// sentences use in the card's sense. Nil on a device without the model, with Apple
/// Intelligence off, while the model is not ready, or where it does not write Chinese.
///
/// Only the Hanzi and the English are the model's. The pinyin is built from the card and the
/// lexicon, since a small model's pinyin cannot be trusted on polyphones.
actor ModelExampleGenerator: ExampleGenerating {
    private let lexicon: any LexiconRepository

    init(lexicon: any LexiconRepository) {
        self.lexicon = lexicon
    }

    func example(for request: ExampleRequest) async throws -> ExampleSentence? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(Locale(identifier: "zh-Hans")) else { return nil }

        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let written = try await session.respond(to: Self.prompt(for: request), generating: WrittenExample.self).content
        let hanzi = written.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pinyin = try await SentencePinyin.spell(hanzi, word: request.hanzi, wordPinyin: request.pinyin, lexicon: lexicon) else {
            return nil
        }
        return ExampleSentence(hanzi: hanzi, pinyin: pinyin, english: written.english.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static let instructions = """
        You write example sentences for someone learning Mandarin Chinese. Write natural, \
        everyday Mandarin in simplified Chinese characters only: no pinyin, no Latin letters, \
        no digits. Keep each sentence short and simple, the kind a beginner's textbook uses.
        """

    /// The learner's own words, up to a number that keeps the prompt small.
    private static let knownLimit = 150

    static func prompt(for request: ExampleRequest) -> String {
        let reading = request.pinyin.isEmpty ? "" : " (\(request.pinyin))"
        var prompt = """
            Write one sentence that uses \(request.hanzi)\(reading) to mean "\(request.meaning)". \
            Use it in that sense only. Keep the sentence under twelve characters.
            """
        let known = request.known.subtracting([request.hanzi]).sorted().prefix(knownLimit)
        if !known.isEmpty {
            prompt += " Besides \(request.hanzi), use only these words if you can: \(known.joined(separator: "、"))."
        }
        return prompt
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
    public static let generator: any ExampleGenerating = ModelExampleGenerator(lexicon: Lexicon.repository)
}
