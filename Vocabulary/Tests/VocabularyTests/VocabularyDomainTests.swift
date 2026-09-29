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

    @Test("search reads pinyin as the dictionary does, ignoring tones, tone numbers and spaces", arguments: [
        "shui", "SHUI", "shui3", "shuí", "  shui ",
    ])
    func searchIgnoresTones(query: String) {
        #expect(Fixtures.water.matches(query))
    }

    @Test("search finds a longer word by its pinyin however the syllables are written", arguments: [
        "yínháng", "yin2hang2", "Yin hang", "yinhang", "hang",
    ])
    func searchJoinsSyllables(query: String) {
        #expect(Word(english: "bank", hanzi: "银行", pinyin: "yín háng").matches(query))
    }

    /// The cost of ignoring tones, as in the dictionary: a toneless query cannot tell 妈
    /// from 马, so both stay in the list.
    @Test("search cannot tell words apart by tone alone")
    func searchTonesIndistinguishable() {
        #expect(Word(english: "mother", hanzi: "妈", pinyin: "mā").matches("mǎ"))
        #expect(Word(english: "horse", hanzi: "马", pinyin: "mǎ").matches("mā"))
    }

    @Test("a Hanzi query matches only Hanzi, and one with no letters matches no pinyin")
    func searchQueryKinds() {
        #expect(!Fixtures.water.matches("水水"))
        #expect(!Word(english: "three", hanzi: "三", pinyin: "sān").matches("3"))
        #expect(SearchQuery("银行").pinyin == nil)
        #expect(SearchQuery("to drink!").pinyin == nil)
        #expect(SearchQuery("Yín háng").pinyin == "yinhang")
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
