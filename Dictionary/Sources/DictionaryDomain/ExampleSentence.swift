import Foundation

/// A sentence that uses a word, from Tatoeba or written on the device, with its pinyin and an
/// English translation.
public nonisolated struct ExampleSentence: Hashable, Sendable {
    public let hanzi: String
    /// With tone marks, a space between words.
    public let pinyin: String
    public let english: String
    /// Its words, as Tatoeba's transcription splits it: 学生 是 我 朋友.
    public let words: [String]
    /// Written by the on-device model rather than a person. Shown as such: in the second
    /// review, 30% of written sentences had a flaw in the Chinese or its translation.
    public let isGenerated: Bool

    public init(hanzi: String, pinyin: String, english: String, words: [String] = [], isGenerated: Bool = false) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
        self.words = words
        self.isGenerated = isGenerated
    }
}

public nonisolated extension Array where Element == ExampleSentence {
    /// The sentence for teaching `word`, meaning `meanings`, to a learner who knows `known`.
    ///
    /// Only a sentence whose English says one of the meanings, the headline before the rest,
    /// so a word is never shown in a sense the card does not give; then the fewest other words
    /// the learner does not know; then the first, which is the easiest as the file orders them.
    /// Nil when none says a meaning, or there are none. A word with no meaning to check, as 了,
    /// or none given, is held to the rest alone.
    func best(teaching word: String, meanings: [String] = [], knowing known: Set<String>) -> ExampleSentence? {
        let checkable = meanings.filter(EnglishMeaning.isCheckable)
        /// 0 for the headline, 1 for another meaning, nil for none.
        let sense = { (sentence: ExampleSentence) -> Int? in
            guard let headline = checkable.first else { return 0 }
            if EnglishMeaning.says(headline, in: sentence.english) { return 0 }
            return checkable.dropFirst().contains { EnglishMeaning.says($0, in: sentence.english) } ? 1 : nil
        }
        let unknown = { (sentence: ExampleSentence) in
            sentence.words.count { $0 != word && !known.contains($0) }
        }
        return enumerated()
            .compactMap { offset, sentence in sense(sentence).map { (sentence, ($0, unknown(sentence), offset)) } }
            .min { $0.1 < $1.1 }?
            .0
    }
}

/// What a sentence is wanted for, when none of the bundled ones will do.
public nonisolated struct ExampleRequest: Hashable, Sendable {
    public let hanzi: String
    public let pinyin: String
    /// The sense the sentence is asked to use: the card's headline.
    public let meaning: String
    /// The card's other meanings. A sentence whose translation says one of these instead is
    /// still in a sense the card gives, as for a Tatoeba sentence.
    public let otherMeanings: [String]

    public init(hanzi: String, pinyin: String, meaning: String, otherMeanings: [String] = []) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meaning = meaning
        self.otherMeanings = otherMeanings
    }
}

/// What one attempt to write a sentence came to.
public nonisolated enum ExampleWriting: Hashable, Sendable {
    /// No model to write with: an older device, Apple Intelligence off, the model not ready,
    /// or no Chinese. Asking again will not help.
    case unavailable
    /// The model declined, as its safety filter did for 小学生, "primary school student". Asking
    /// again may.
    case refused
    case written(ExampleSentence)
}

/// Writes an example sentence on the device. A sentence it writes is checked by
/// `GenerateExampleUseCase` before it is shown.
public nonisolated protocol ExampleGenerating: Sendable {
    func example(for request: ExampleRequest) async throws -> ExampleWriting
}

/// The bundled example sentences.
public nonisolated protocol ExampleRepository: Sendable {
    /// Up to ten, easiest first by HSK level. Only sentences that say this reading, so 长 cháng's
    /// never include one where it is zhǎng. `pinyin` in any spelling; empty for whichever
    /// reading the dictionary lists first. Empty when there are none.
    func examples(forHanzi hanzi: String, pinyin: String) async throws -> [ExampleSentence]
}
