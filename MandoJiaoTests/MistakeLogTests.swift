import SwiftData
import Testing
@testable import MandoJiao

@Suite("Mistake bookkeeping")
@MainActor
struct MistakeLogTests {
    /// Held for the life of the test. Letting the container go out of scope tears the
    /// store down underneath the words, and touching one then traps.
    private let container: ModelContainer
    private let context: ModelContext
    private let water: VocabWord
    private let tea: VocabWord
    private let book: VocabWord

    init() throws {
        container = try ModelContainer(
            for: VocabWord.self, Deck.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext

        water = VocabWord(english: "water", hanzi: "水", pinyin: "shuǐ")
        tea = VocabWord(english: "tea", hanzi: "茶", pinyin: "chá")
        book = VocabWord(english: "book", hanzi: "书", pinyin: "shū")
        [water, tea, book].forEach(context.insert)
    }

    @Test("misses accumulate against every word involved")
    func missesAccumulate() {
        MistakeLog.apply(misses: [water.uuid: 2, tea.uuid: 2], cleanSolves: [:], in: context)

        #expect(water.missCount == 2)
        #expect(tea.missCount == 2)
        #expect(water.lastMissedAt != nil)
    }

    @Test("a word that was never missed stays clean")
    func cleanWordsStayClean() {
        MistakeLog.apply(misses: [:], cleanSolves: [book.uuid: 3], in: context)

        #expect(book.missCount == 0)
        #expect(book.lastMissedAt == nil)
    }

    @Test("solving a word later in the lesson that missed it does not cancel the miss")
    func recoveryDoesNotCancelAMiss() {
        // Without this, a single miss would wipe itself out the moment the word came
        // round again, which happens constantly with a small pool, and the mistakes list
        // would stay permanently empty.
        MistakeLog.apply(misses: [water.uuid: 2], cleanSolves: [:], in: context)
        MistakeLog.apply(misses: [water.uuid: 1], cleanSolves: [water.uuid: 2], in: context)

        #expect(water.missCount == 3)
    }

    @Test("a clean solve works one mistake off the list")
    func cleanSolveDecrements() {
        MistakeLog.apply(misses: [tea.uuid: 2], cleanSolves: [:], in: context)
        MistakeLog.apply(misses: [:], cleanSolves: [tea.uuid: 1], in: context)

        #expect(tea.missCount == 1)
    }

    @Test("a word at three mistakes takes three drills to clear")
    func oneOffPerDrill() {
        MistakeLog.apply(misses: [water.uuid: 3], cleanSolves: [:], in: context)

        for remaining in [2, 1, 0] {
            MistakeLog.apply(misses: [:], cleanSolves: [water.uuid: 1], in: context)
            #expect(water.missCount == remaining)
        }
    }

    @Test("clean solves cannot push a count below zero")
    func neverNegative() {
        MistakeLog.apply(misses: [:], cleanSolves: [book.uuid: 5], in: context)
        #expect(book.missCount == 0)
    }

    @Test("clearing the list resets the count and the date")
    func clearAll() {
        MistakeLog.apply(misses: [water.uuid: 2, tea.uuid: 1], cleanSolves: [:], in: context)
        MistakeLog.clearAll(in: context)

        #expect(water.missCount == 0)
        #expect(water.lastMissedAt == nil)
        #expect(tea.missCount == 0)
    }
}
