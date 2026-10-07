import Foundation
import Testing
import VocabularyDomain
@testable import ProgressDomain

@Suite("Today's plan")
nonisolated struct TodayPlannerTests {
    private let now = Date(timeIntervalSince1970: 100 * 86_400)

    /// A word last answered `daysAgo` with this stability, or never answered.
    private func word(_ english: String, _ hanzi: String, stability: Double? = nil, daysAgo: Double = 0) -> Word {
        let memory = stability.map { WordMemory(stability: $0, lastAnsweredAt: now.addingTimeInterval(-daysAgo * 86_400)) } ?? .new
        return Word(english: english, hanzi: hanzi, memory: memory)
    }

    private func plan(_ words: [Word], decks: [DeckSummary] = [], current: LessonSource? = nil, settings: LessonSettings = .default) -> TodayPlan? {
        TodayPlanner.suggest(
            vocabulary: Vocabulary(words: words, decks: decks), current: current,
            settings: settings, boardSize: 5, now: now
        )
    }

    private let fresh = ["water 水", "tea 茶", "book 书", "car 车", "big 大", "small 小", "dog 狗"].map { $0.split(separator: " ") }

    @Test("with nothing answered, it teaches five new words, matches them, then recognises each")
    func newWords() throws {
        let words = fresh.map { word(String($0[0]), String($0[1])) }
        let plan = try #require(plan(words))
        #expect(plan.theme == .newWords)
        #expect(plan.synopsis == "Learn 5 new words.")
        let taught = plan.steps.compactMap { if case .teach(let pair) = $0 { pair } else { nil } }
        #expect(taught.count == 5)
        guard case .match(let board) = plan.steps[5] else {
            Issue.record("expected a board after teaching")
            return
        }
        #expect(board == taught)
        #expect(plan.steps.dropFirst(6).allSatisfy { if case .recall(_, .recognise) = $0 { true } else { false } })
    }

    @Test("new words come from the current deck first, which it then marks practised, and the board is padded from elsewhere")
    func fromCurrentDeck() throws {
        let words = fresh.map { word(String($0[0]), String($0[1])) }
        let deck = DeckSummary(id: UUID(), name: "Animals", createdAt: now, wordIDs: [words[6].id])
        let plan = try #require(plan(words, decks: [deck], current: .deck(deck.id)))
        #expect(plan.synopsis == "Learn 1 new word from Animals.")
        #expect(plan.source == .deck(deck.id))
        guard case .match(let board) = plan.steps[1] else {
            Issue.record("expected a board")
            return
        }
        #expect(board.first?.hanzi == "狗")
        #expect(board.count == 5)
    }

    @Test("with enough words fading it reviews them instead, weakest first, recognising weak words and typing strong ones")
    func review() throws {
        var words = (0..<8).map { word("weak \($0)", "弱\($0)", stability: 2, daysAgo: Double(3 + $0)) }
        words.append(word("strong", "强", stability: 30, daysAgo: 40))
        let plan = try #require(plan(words + [word("new", "新")]))
        #expect(plan.theme == .review)
        #expect(plan.synopsis == "Practise 9 words you've met that are starting to fade.")
        guard case .recall(let weakest, .recognise) = plan.steps.first else {
            Issue.record("expected the weakest recognised first")
            return
        }
        #expect(weakest.hanzi == "弱7")
        // Known, though fading: its Hanzi is typed.
        #expect(plan.steps.contains(.recall(words[8].pair, .produce)))
    }

    @Test("a few fading words wait behind new words, reviewed after them")
    func fewDue() throws {
        let due = [word("old", "旧", stability: 2, daysAgo: 5)]
        let plan = try #require(plan(fresh.map { word(String($0[0]), String($0[1])) } + due))
        #expect(plan.theme == .newWords)
        #expect(plan.synopsis == "Learn 5 new words, then review 1 you've met before.")
        #expect(plan.steps.last == .recall(due[0].pair, .recognise))
    }

    @Test("a word not yet fading is left alone, and with nothing new or fading there is no plan")
    func nothingToDo() {
        #expect(plan([word("fresh", "新", stability: 30, daysAgo: 1)]) == nil)
        #expect(plan([]) == nil)
    }

    @Test("learnt words are left out when the settings skip them")
    func skipsLearnt() {
        let learnt = Word(english: "water", hanzi: "水", memory: WordMemory.new.markedLearnt(at: now.addingTimeInterval(-200 * 86_400)))
        #expect(plan([learnt]) != nil)
        #expect(plan([learnt], settings: LessonSettings(skipsLearntWords: true)) == nil)
    }
}
