import Foundation

/// A sentence that uses a word, from Tatoeba, with its pinyin and an English translation.
public nonisolated struct ExampleSentence: Hashable, Sendable {
    public let hanzi: String
    /// With tone marks, a space between words.
    public let pinyin: String
    public let english: String

    public init(hanzi: String, pinyin: String, english: String) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
    }
}

/// The bundled example sentences.
public nonisolated protocol ExampleRepository: Sendable {
    /// Best first: shortest and easiest. Only sentences that say this reading, so 长 cháng's
    /// never include one where it is zhǎng. `pinyin` in any spelling; empty for whichever
    /// reading the dictionary lists first. Empty when there are none.
    func examples(forHanzi hanzi: String, pinyin: String) async throws -> [ExampleSentence]
}
