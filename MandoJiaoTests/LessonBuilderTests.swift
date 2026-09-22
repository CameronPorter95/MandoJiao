import Testing
@testable import MandoJiao

@Suite("Matching lesson building")
struct LessonBuilderTests {
    private let pool = [
        ("water", "水"), ("tea", "茶"), ("to eat", "吃"), ("to drink", "喝"),
        ("book", "书"), ("home", "家"), ("cat", "猫"), ("dog", "狗")
    ].map { WordPair(english: $0.0, hanzi: $0.1, pinyin: "") }

    @Test("a lesson is ten rounds of five")
    func shape() throws {
        let plan = try #require(LessonBuilder.makeLesson(title: "t", from: pool))
        #expect(plan.exercises.count == 10)
        #expect(plan.exercises.allSatisfy { $0.count == 5 })
    }

    @Test("a pair never appears twice on one board")
    func noRepeatsWithinABoard() throws {
        let plan = try #require(LessonBuilder.makeLesson(title: "t", from: pool))
        #expect(plan.exercises.allSatisfy { Set($0.map(\.id)).count == 5 })
    }

    @Test("no board shows the same english or hanzi twice")
    func noAmbiguousBoards() throws {
        // Two tiles reading the same would make the board unsolvable, which is the bug
        // visible in Duolingo's own version of this exercise.
        let plan = try #require(LessonBuilder.makeLesson(title: "t", from: pool))
        for exercise in plan.exercises {
            #expect(Set(exercise.map(\.english)).count == 5)
            #expect(Set(exercise.map(\.hanzi)).count == 5)
        }
    }

    @Test("a pool below one board's worth cannot make a lesson")
    func tooFewWords() {
        #expect(LessonBuilder.makeLesson(title: "t", from: Array(pool.prefix(4))) == nil)
    }

    @Test("exactly five words still fills ten rounds by coming round again")
    func smallestUsablePool() throws {
        let plan = try #require(LessonBuilder.makeLesson(title: "t", from: Array(pool.prefix(5))))
        #expect(plan.exercises.count == 10)
    }

    @Test("dealing from a bag covers the whole pool before repeating")
    func bagCoversThePool() throws {
        let ten = (0..<10).map { WordPair(english: "e\($0)", hanzi: "h\($0)", pinyin: "") }
        let plan = try #require(LessonBuilder.makeLesson(title: "t", from: ten))
        #expect(Set(plan.exercises.flatMap { $0 }.map(\.id)).count == 10)
    }

    @Test("an unsatisfiable board constraint relaxes instead of hanging")
    func relaxesWhenImpossible() throws {
        // Five words that all read "hello" cannot fill a board without a duplicate, so
        // the builder has to give up on that rule rather than spin.
        let clashing = (0..<5).map { WordPair(english: "hello", hanzi: "字\($0)", pinyin: "") }
        let plan = try #require(LessonBuilder.makeLesson(title: "t", from: clashing))
        #expect(plan.exercises.first?.count == 5)
        // The one rule it must never break, even relaxed.
        #expect(plan.exercises.allSatisfy { Set($0.map(\.id)).count == 5 })
    }
}
