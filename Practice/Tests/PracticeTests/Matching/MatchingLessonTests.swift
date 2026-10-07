import Foundation
import Testing
@testable import PracticeDomain
import LibraryDomain

@Suite("Matching lesson tallies")
struct MatchingLessonTests {
    private let pairs = [
        WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
        WordPair(english: "tea", hanzi: "茶", pinyin: "chá"),
        WordPair(english: "book", hanzi: "书", pinyin: "shū"),
        WordPair(english: "car", hanzi: "车", pinyin: "chē"),
        WordPair(english: "big", hanzi: "大", pinyin: "dà"),
    ]

    private func makeLesson(boards: Int = 2) -> MatchingLesson {
        MatchingLesson(plan: MatchingPlan(title: "t", exercises: Array(repeating: pairs, count: boards)))
    }

    @Test("a clean match counts as knowing the word")
    func cleanMatch() {
        var lesson = makeLesson()
        lesson.match(pairs[0])

        #expect(lesson.cleanSolvesByPairID[pairs[0].id] == 1)
        #expect(lesson.missesByPairID.isEmpty)
        #expect(lesson.missCount == 0)
    }

    @Test("a wrong guess counts once, against both words involved")
    func missImplicatesBoth() {
        var lesson = makeLesson()
        _ = lesson.tap(lesson.tile(pairs[0], .english))
        _ = lesson.tap(lesson.tile(pairs[1], .hanzi))

        #expect(lesson.missCount == 1)
        #expect(lesson.missesByPairID == [pairs[0].id: 1, pairs[1].id: 1])
    }

    @Test("matching a word after getting it wrong on the same board is not a clean solve")
    func recoveryIsNotClean() {
        var lesson = makeLesson()
        _ = lesson.tap(lesson.tile(pairs[0], .english))
        _ = lesson.tap(lesson.tile(pairs[1], .hanzi))
        lesson.match(pairs[0])

        #expect(lesson.cleanSolvesByPairID[pairs[0].id] == nil)
        #expect(lesson.missesByPairID[pairs[0].id] == 1)
    }

    @Test("each match is an answer, carrying the wrong guesses its word was part of on that board")
    func answers() {
        var lesson = makeLesson()
        _ = lesson.tap(lesson.tile(pairs[0], .english))
        _ = lesson.tap(lesson.tile(pairs[1], .hanzi))
        lesson.match(pairs[1])
        lesson.match(pairs[2])

        #expect(lesson.answers == [
            Answer(wordID: pairs[1].id, exercise: .matching, direction: nil, isCorrect: true, wrongAttempts: 1),
            Answer(wordID: pairs[2].id, exercise: .matching, direction: nil, isCorrect: true, wrongAttempts: 0),
            // Closed now, water was guessed wrong and never matched, so it counts as wrong.
            Answer(wordID: pairs[0].id, exercise: .matching, direction: nil, isCorrect: false, wrongAttempts: 1),
        ])
    }

    @Test("a word is answered once per board it is on, and an untried word not at all")
    func answersPerBoard() {
        var lesson = makeLesson(boards: 2)
        _ = lesson.tap(lesson.tile(pairs[0], .english))
        _ = lesson.tap(lesson.tile(pairs[1], .hanzi))
        pairs.forEach { lesson.match($0) }
        lesson.advance()
        lesson.match(pairs[0])

        let water = lesson.answers.filter { $0.wordID == pairs[0].id }
        #expect(water.map(\.wrongAttempts) == [1, 0])
        #expect(water.map(\.isCorrect) == [true, true])
        // The second board's other words were never tried.
        #expect(lesson.answers.count == pairs.count + 1)
    }

    @Test("a cleared board ignores taps until the lesson moves on")
    func clearedBoardIsInert() {
        var lesson = makeLesson()
        pairs.forEach { lesson.match($0) }
        #expect(lesson.board.isComplete)

        #expect(lesson.tap(lesson.tile(pairs[0], .english)) == .ignored)
        #expect(lesson.exerciseIndex == 0)
    }

    @Test("advancing moves to the next board, and past the last one finishes")
    func advancing() {
        var lesson = makeLesson(boards: 2)
        pairs.forEach { lesson.match($0) }
        lesson.advance()
        #expect(lesson.exerciseIndex == 1)
        #expect(lesson.board.matchedCount == 0)
        #expect(!lesson.isFinished)

        pairs.forEach { lesson.match($0) }
        lesson.advance()
        #expect(lesson.isFinished)
        #expect(lesson.progress == 1)

        lesson.advance()
        #expect(lesson.exerciseIndex == 1)
    }

    @Test("progress moves with each match inside a board")
    func progressWithinBoard() {
        var lesson = makeLesson(boards: 2)
        lesson.match(pairs[0])

        #expect(lesson.progress == 0.1)
    }

    @Test("the review puts the most-missed words first and keeps them out of the clean list")
    func review() {
        var lesson = makeLesson()
        _ = lesson.tap(lesson.tile(pairs[0], .english))
        _ = lesson.tap(lesson.tile(pairs[1], .hanzi))
        _ = lesson.tap(lesson.tile(pairs[0], .english))
        _ = lesson.tap(lesson.tile(pairs[2], .hanzi))

        #expect(lesson.missedPairs.map(\.pair.english) == ["water", "book", "tea"])
        #expect(lesson.cleanPairs.map(\.english) == ["big", "car"])
        #expect(lesson.totalMatches == 10)
    }
}

extension MatchingLesson {
    func tile(_ pair: WordPair, _ side: TileSide) -> Tile {
        let tiles = side == .english ? board.englishTiles : board.hanziTiles
        return tiles.first { $0.pairID == pair.id }!
    }

    mutating func match(_ pair: WordPair) {
        _ = tap(tile(pair, .english))
        _ = tap(tile(pair, .hanzi))
    }
}
