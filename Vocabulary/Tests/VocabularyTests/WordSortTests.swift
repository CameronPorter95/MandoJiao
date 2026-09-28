import Foundation
import Testing
@testable import VocabularyDomain

@Suite("Sorting words")
nonisolated struct WordSortTests {
    private let day: TimeInterval = 86_400
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func vocabulary(_ words: [Word]) -> Vocabulary {
        Vocabulary(words: words, decks: [], folders: [])
    }

    private func word(_ english: String, _ hanzi: String, _ pinyin: String, days: Double = 0, misses: Int = 0) -> Word {
        Word(meanings: [english], hanzi: hanzi, pinyin: pinyin, missCount: misses, createdAt: base.addingTimeInterval(days * day))
    }

    @Test("English sorts by the headline as a tile shows it: asides dropped, case ignored")
    func english() {
        let words = [
            word("(general classifier)", "个", "gè"),
            word("Europe", "欧洲", "Ōuzhōu"),
            word("apple", "苹果", "píngguǒ"),
            word("to drink", "喝", "hē"),
        ]
        let sorted = vocabulary(words).words(sortedBy: .default).map(\.hanzi)
        #expect(sorted == ["苹果", "欧洲", "个", "喝"])
        let descending = vocabulary(words).words(sortedBy: WordSort(field: .english, ascending: false)).map(\.hanzi)
        #expect(descending == sorted.reversed())
    }

    @Test("pinyin ignores tones and case first, so hē and hè sit together")
    func pinyin() {
        let words = [word("to shout", "喝彩", "hècǎi"), word("black", "黑", "hēi"), word("to drink", "喝", "hē"), word("Europe", "欧洲", "Ōuzhōu")]
        #expect(vocabulary(words).words(sortedBy: WordSort(field: .pinyin, ascending: true)).map(\.hanzi) == ["喝", "喝彩", "黑", "欧洲"])
    }

    @Test("date added and mistakes fall back to English on a tie")
    func datesAndMistakes() {
        let words = [
            word("tea", "茶", "chá", days: 1, misses: 2),
            word("water", "水", "shuǐ", days: 3),
            word("book", "书", "shū", days: 1, misses: 2),
        ]
        let latest = WordSort(field: .dateAdded, ascending: false)
        #expect(vocabulary(words).words(sortedBy: latest).map(\.hanzi) == ["水", "书", "茶"])
        let most = WordSort(field: .mistakes, ascending: false)
        #expect(vocabulary(words).words(sortedBy: most).map(\.hanzi) == ["书", "茶", "水"])
    }
}
