import Foundation
import Testing
@testable import MandoJiao

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
        try await CreateDeckUseCase(repository: repository)(name: "   ")
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

@Suite("Effect channel")
@MainActor
struct EffectChannelTests {
    @Test("an effect sent with nobody listening waits for the next listener")
    func buffersWithoutAListener() async {
        let channel = EffectChannel<Int>()
        channel.send(1)

        let log = EffectLog(channel.stream())

        #expect(await log.equals([1]))
    }

    @Test("a listener that went away does not swallow later effects")
    func survivesADisappearance() async {
        // What happens to a Route's .task when another screen is pushed over it.
        let channel = EffectChannel<Int>()
        let first = Task { for await _ in channel.stream() {} }
        await settle()
        first.cancel()
        await settle()

        channel.send(2)
        let log = EffectLog(channel.stream())

        #expect(await log.equals([2]))
    }

    @Test("a new listener replaces the old one")
    func oneListener() async {
        let channel = EffectChannel<Int>()
        let old = EffectLog(channel.stream())
        let new = EffectLog(channel.stream())

        channel.send(3)

        #expect(await new.equals([3]))
        #expect(old.effects.isEmpty)
    }
}
