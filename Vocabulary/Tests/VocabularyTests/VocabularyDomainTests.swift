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
}
