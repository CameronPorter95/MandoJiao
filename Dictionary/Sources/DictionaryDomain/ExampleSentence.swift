import Foundation

/// A sentence that uses a word, from Tatoeba, with its pinyin and an English translation.
public nonisolated struct ExampleSentence: Hashable, Sendable {
    public let hanzi: String
    /// With tone marks, a space between words.
    public let pinyin: String
    public let english: String
    /// Its words, as Tatoeba's transcription splits it: 学生 是 我 朋友.
    public let words: [String]

    public init(hanzi: String, pinyin: String, english: String, words: [String] = []) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
        self.words = words
    }
}

public nonisolated extension Array where Element == ExampleSentence {
    /// The sentence for teaching `word` to a learner who knows `known`: the one with the
    /// fewest other words they do not know, and among those the first, which is the easiest
    /// as the file orders them. Nil when there are none.
    func best(teaching word: String, knowing known: Set<String>) -> ExampleSentence? {
        let unknown = { (sentence: ExampleSentence) in
            sentence.words.count { $0 != word && !known.contains($0) }
        }
        return enumerated().min { (unknown($0.element), $0.offset) < (unknown($1.element), $1.offset) }?.element
    }
}

/// The bundled example sentences.
public nonisolated protocol ExampleRepository: Sendable {
    /// Up to ten, easiest first by HSK level. Only sentences that say this reading, so 长 cháng's
    /// never include one where it is zhǎng. `pinyin` in any spelling; empty for whichever
    /// reading the dictionary lists first. Empty when there are none.
    func examples(forHanzi hanzi: String, pinyin: String) async throws -> [ExampleSentence]
}
