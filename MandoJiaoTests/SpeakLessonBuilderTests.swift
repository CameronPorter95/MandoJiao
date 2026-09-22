import Testing
@testable import MandoJiao

@Suite("Speech drill building")
struct SpeakLessonBuilderTests {
    private let pool = [
        ("water", "水"), ("tea", "茶"), ("to eat", "吃"), ("to drink", "喝"), ("book", "书")
    ].map { WordPair(english: $0.0, hanzi: $0.1, pinyin: "") }

    @Test("one word is enough for a drill")
    func singleWordLesson() throws {
        // The whole reason this exercise exists. The matching board needed five pairs and
        // padded a short mistakes list with unrelated words to reach them.
        let plan = try #require(SpeakLessonBuilder.makeLesson(title: "t", from: [pool[0]]))
        #expect(plan.cards.count == 1)
    }

    @Test("an empty pool makes no drill")
    func emptyPool() {
        #expect(SpeakLessonBuilder.makeLesson(title: "t", from: []) == nil)
    }

    @Test("every word gets exactly one card, with nothing padded in")
    func oneCardPerWord() throws {
        let plan = try #require(SpeakLessonBuilder.makeLesson(title: "t", from: pool))
        #expect(plan.cards.count == pool.count)
    }

    @Test("pool order is kept, so the worst offenders come first")
    func orderIsPreserved() throws {
        let plan = try #require(SpeakLessonBuilder.makeLesson(title: "t", from: pool))
        #expect(plan.cards.map(\.english) == pool.map(\.english))
    }

    @Test("a word cannot appear twice in one drill")
    func noDuplicates() throws {
        let plan = try #require(SpeakLessonBuilder.makeLesson(title: "t", from: pool + pool))
        #expect(plan.cards.count == pool.count)
    }

    @Test("a drill is capped at twenty cards")
    func cap() throws {
        let big = (0..<30).map { WordPair(english: "e\($0)", hanzi: "h\($0)", pinyin: "") }
        let plan = try #require(SpeakLessonBuilder.makeLesson(title: "t", from: big))
        #expect(plan.cards.count == SpeakLessonBuilder.maxCards)
    }

    @Test("a word missing either side is not a card")
    func incompleteWordsAreSkipped() {
        #expect(SpeakLessonBuilder.makeLesson(title: "t", from: [
            WordPair(english: "", hanzi: "水", pinyin: "")
        ]) == nil)
        #expect(SpeakLessonBuilder.makeLesson(title: "t", from: [
            WordPair(english: "water", hanzi: "", pinyin: "")
        ]) == nil)
    }
}
