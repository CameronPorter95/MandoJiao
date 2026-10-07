import DictionaryDomain
import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

@Suite("Vocabulary rules")
struct VocabularyDomainTests {
    @Test("the mistakes list is worst first, then most recently missed, and skips unusable words")
    func mistakesOrder() {
        let blankWithMistakes = Word(english: "", hanzi: "空", missCount: 9)
        let vocabulary = Vocabulary(words: Fixtures.words + [blankWithMistakes], decks: [])

        #expect(vocabulary.mistakeWords.map(\.english) == ["mobile phone", "book", "tea"])
    }

    @Test("a deck's words come back in the deck's order, skipping any that are gone")
    func deckOrder() {
        let deck = DeckSummary(id: UUID(), name: "d", createdAt: .now, wordIDs: [Fixtures.green.id, UUID(), Fixtures.water.id])
        let vocabulary = Vocabulary(words: Fixtures.words, decks: [deck])

        #expect(vocabulary.words(in: deck).map(\.english) == ["green", "water"])
    }

    @Test("a deck's usable count leaves out words missing English or Hanzi")
    func usableCount() {
        #expect(Fixtures.vocabulary.usableWordCount(in: Fixtures.smallDeck) == 1)
    }

    @Test("search matches English and pinyin ignoring case, and Hanzi exactly")
    func search() {
        #expect(Fixtures.water.matches("WAT"))
        #expect(Fixtures.water.matches("shuǐ"))
        #expect(Fixtures.water.matches("水"))
        #expect(Fixtures.water.matches("  "))
        #expect(!Fixtures.water.matches("tea"))
    }

    @Test("search reads pinyin as the dictionary does, ignoring case and spaces, and tones unless written", arguments: [
        "shui", "SHUI", "shui3", "shu3i", "shuǐ", "shǔi", "SHUǏ", "shuĭ", "  shui ",
    ])
    func searchReadsPinyin(query: String) {
        #expect(Fixtures.water.matches(query))
    }

    @Test("a tone written, by mark or number, finds only that tone", arguments: [
        "shuí", "shui2", "shuī", "shui4", "shu4i",
    ])
    func searchWrittenTone(query: String) {
        #expect(!Fixtures.water.matches(query))
    }

    @Test("search finds a longer word by its pinyin however the syllables are written", arguments: [
        "yínháng", "yin2hang2", "Yin hang", "yinhang", "hang", "yín", "háng", "yinháng", "hang2",
    ])
    func searchJoinsSyllables(query: String) {
        #expect(Word(english: "bank", hanzi: "银行", pinyin: "yín háng").matches(query))
    }

    @Test("a longer word is not found by a syllable written in another tone", arguments: [
        "yìnháng", "yinhàng", "yin2hang4", "hang4",
    ])
    func searchJoinsSyllablesByTone(query: String) {
        #expect(!Word(english: "bank", hanzi: "银行", pinyin: "yín háng").matches(query))
    }

    @Test("a toneless query finds every tone, and a toned one only its own")
    func searchTellsTonesApart() {
        let mother = Word(english: "mother", hanzi: "妈", pinyin: "mā")
        let horse = Word(english: "horse", hanzi: "马", pinyin: "mǎ")
        let particle = Word(english: "question particle", hanzi: "吗", pinyin: "ma")
        #expect([mother, horse, particle].allSatisfy { $0.matches("ma") })
        #expect([mother, horse, particle].filter { $0.matches("mǎ") } == [horse])
        #expect([mother, horse, particle].filter { $0.matches("ma1") } == [mother])
    }

    /// The cost of a tone belonging to a run of vowels rather than a syllable: 西安 Xī'ān
    /// is one run of "ia" to a query that does not split it, so "xiān", meaning 先, finds it.
    @Test("a toned query cannot tell apart two syllables it reads as one")
    func searchToneAcrossSyllables() {
        let xian = Word(english: "Xi'an", hanzi: "西安", pinyin: "Xī'ān")
        #expect(xian.matches("xiān"))
        #expect(!xian.matches("xiàn"))
    }

    @Test("a word is a dictionary reading however its pinyin is typed", arguments: [
        "yínháng", "yín háng", "Yínháng", "yin2hang2", "yin2 hang2",
    ])
    func wordIsReading(pinyin: String) {
        let entry = DictionaryEntry(simplified: "银行", traditional: "銀行", pinyin: "yínháng", isPreferred: true, senses: ["bank"])
        #expect(Word(english: "bank", hanzi: "银行", pinyin: pinyin).isReading(of: entry))
    }

    @Test("a word is not a reading with other tones, other Hanzi, or no pinyin")
    func wordIsNotReading() {
        let xing = DictionaryEntry(simplified: "行", traditional: "行", pinyin: "xíng", isPreferred: true, senses: ["to walk"])
        #expect(!Word(english: "row", hanzi: "行", pinyin: "háng").isReading(of: xing))
        #expect(!Word(english: "walk", hanzi: "行", pinyin: "xìng").isReading(of: xing))
        #expect(!Word(english: "walk", hanzi: "行", pinyin: "xing").isReading(of: xing))
        #expect(!Word(english: "walk", hanzi: "走", pinyin: "xíng").isReading(of: xing))
        #expect(!Word(english: "walk", hanzi: "行").isReading(of: xing))
    }

    @Test("a neutral tone is a reading whether written with a 5 or nothing")
    func wordIsReadingNeutral() {
        let xiexie = DictionaryEntry(simplified: "谢谢", traditional: "謝謝", pinyin: "xièxie", isPreferred: true, senses: ["thanks"])
        #expect(Word(english: "thanks", hanzi: "谢谢", pinyin: "xie4xie5").isReading(of: xiexie))
        #expect(Word(english: "thanks", hanzi: "谢谢", pinyin: "xie4xie").isReading(of: xiexie))
    }

    @Test("a Hanzi query matches only Hanzi, and one with no letters matches no pinyin")
    func searchQueryKinds() {
        #expect(!Fixtures.water.matches("水水"))
        #expect(!Word(english: "three", hanzi: "三", pinyin: "sān").matches("3"))
        #expect(SearchQuery("银行").pinyin == nil)
        #expect(SearchQuery("to drink!").pinyin == nil)
        #expect(SearchQuery("Yín háng").pinyin?.letters == "yinhang")
    }

    @Test("a draft needs English and Hanzi, and is saved trimmed")
    func drafts() {
        #expect(!WordDraft(english: " ", hanzi: "水").isComplete)
        #expect(!WordDraft(english: "water", hanzi: "").isComplete)
        #expect(WordDraft(english: "water", hanzi: "水").isComplete)
        #expect(WordDraft(english: " water ", hanzi: " 水", pinyin: "shuǐ ").trimmed
            == WordDraft(english: "water", hanzi: "水", pinyin: "shuǐ"))
    }

    @Test("an incomplete draft or a blank deck name writes nothing")
    func useCaseGuards() async throws {
        let repository = FakeVocabularyRepository()
        try await SaveWordUseCase(repository: repository)(id: nil, draft: WordDraft(english: "water"))
        try await CreateDeckUseCase(repository: repository)(name: "   ", folderID: UUID())
        try await RecordLessonResultsUseCase(repository: repository)(LessonResults(misses: [:], cleanSolves: [:]))
        try await DeleteWordsUseCase(repository: repository)(ids: [])

        #expect(await repository.writes.isEmpty)
    }

    @Test("saving trims every field")
    func saveTrims() async throws {
        let repository = FakeVocabularyRepository()
        try await SaveWordUseCase(repository: repository)(id: nil, draft: WordDraft(english: " water ", hanzi: "水 ", pinyin: " shuǐ"))

        #expect(await repository.writes == ["saveWord new water|水|shuǐ"])
    }

    @Test("the first meaning is the headline; a lesson gets it short, with the rest to reveal")
    func meanings() {
        let word = Word(meanings: ["(bound form) row, line", "line of business, trade"], hanzi: "行", pinyin: "háng")
        #expect(word.english == "(bound form) row, line")
        #expect(word.pair.english == "row, line")
        #expect(word.pair.otherMeanings == ["line of business, trade"])
        #expect(word.pair.meanings == ["row, line", "line of business, trade"])
        #expect(word.matches("TRADE"))
        #expect(Word(english: "water", hanzi: "水").meanings == ["water"])
        #expect(Word(english: "", hanzi: "空").meanings.isEmpty)
    }

    @Test("a draft drops blank and repeated meanings, keeping the first of each, and needs one")
    func draftMeanings() {
        let draft = WordDraft(meanings: [" to drink ", "", "To Drink", "to shout"], hanzi: "喝")
        #expect(draft.trimmed.meanings == ["to drink", "to shout"])
        #expect(draft.isComplete)
        #expect(!WordDraft(meanings: ["  "], hanzi: "喝").isComplete)
    }
}

@Suite("Saved readings")
@MainActor
struct VocabularySavedReadingsTests {
    @Test("the dictionary sees each saved word's id, Hanzi and pinyin, live")
    func savedReadings() async throws {
        let repository = FakeVocabularyRepository(Vocabulary(words: [Word(english: "row", hanzi: "行", pinyin: "háng")], decks: [], folders: []))
        var stream = VocabularySavedReadings(repository: repository).savedReadings().makeAsyncIterator()
        let first = try #require(await stream.next())
        #expect(first.map(\.hanzi) == ["行"])
        #expect(first.map(\.pinyin) == ["háng"])

        try await repository.saveWord(id: nil, draft: WordDraft(english: "to drink", hanzi: "喝", pinyin: "hē"), deckID: nil)
        let second = try #require(await stream.next())
        #expect(Set(second.map(\.hanzi)) == ["行", "喝"])
    }
}
