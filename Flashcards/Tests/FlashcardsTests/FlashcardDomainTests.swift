import Foundation
import Testing
@testable import FlashcardsDomain
import VocabularyDomain

/// Deterministic, so the random choices of a plan can be pinned.
nonisolated struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

nonisolated enum Words {
    static let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    static let tea = WordPair(english: "tea", hanzi: "茶", pinyin: "chá")
    static let book = WordPair(english: "book", hanzi: "书", pinyin: "shū")
    static let tell = WordPair(english: "to tell, to inform", hanzi: "告诉", pinyin: "gàosu")
    static let drink = WordPair(english: "to drink", hanzi: "喝", pinyin: "hē", otherMeanings: ["to shout"])
    static let dad = WordPair(english: "(coll.) father, dad", hanzi: "爸爸", pinyin: "bàba")
    static let look = WordPair(english: "to see", hanzi: "看", pinyin: "kàn", otherMeanings: ["to look at"])
    static let see = WordPair(english: "to see", hanzi: "见", pinyin: "jiàn")
    static let all = [water, tea, book, tell, drink, dad, look, see]
}

@Suite("Flash card plans")
struct FlashcardPlanTests {
    @Test("one card per word with Hanzi and a meaning, at most the limit, and none for nothing usable")
    func cards() throws {
        var random = SeededRandom(1)
        let blank = WordPair(english: "", hanzi: "空")
        let plan = try #require(FlashcardPlanBuilder.makeLesson(
            title: "t", from: Words.all + [Words.water, blank], maxCards: 5, using: &random
        ))
        #expect(plan.cardCount == 5)
        #expect(Set(plan.cards.map(\.word.hanzi)).count == 5)
        #expect(!plan.cards.contains { $0.word.hanzi == "空" })
        #expect(FlashcardPlanBuilder.makeLesson(title: "t", from: [blank], using: &random) == nil)
    }

    @Test("over many plans both directions and both formats come up, and only the two directions")
    func choicesVary() {
        var random = SeededRandom(2)
        var directions = Set<Answer.Direction>()
        var formats = Set<Bool>()
        for _ in 0..<20 {
            for card in FlashcardPlanBuilder.makeLesson(title: "t", from: Words.all, using: &random)?.cards ?? [] {
                directions.insert(card.direction)
                if case .picked = card.format { formats.insert(true) } else { formats.insert(false) }
            }
        }
        #expect(directions == [.chineseToEnglish, .englishToChinese])
        #expect(formats == [true, false])
    }

    @Test("a picked card's options are four, hold the word, and never another word sharing its Hanzi or a meaning")
    func options() {
        var random = SeededRandom(3)
        for _ in 0..<20 {
            for card in FlashcardPlanBuilder.makeLesson(title: "t", from: Words.all, using: &random)?.cards ?? [] {
                guard case .picked(let options) = card.format else { continue }
                #expect(options.count == FlashcardPlanBuilder.optionCount)
                #expect(options.contains(card.word))
                #expect(!options.contains { $0 != card.word && ($0.hanzi == card.word.hanzi || $0.sharesMeaning(with: card.word)) })
            }
        }
    }

    @Test("with too few words to fill the options safely, every card is typed")
    func tooFewToPick() {
        var random = SeededRandom(4)
        for _ in 0..<10 {
            let plan = FlashcardPlanBuilder.makeLesson(title: "t", from: [Words.water, Words.tea, Words.book], using: &random)
            #expect(plan?.cards.allSatisfy { $0.format == .typed } == true)
        }
    }

    @Test("a word sharing a meaning in the lesson is accepted too, since the English cannot tell them apart")
    func alsoAccepted() throws {
        var random = SeededRandom(5)
        let plan = try #require(FlashcardPlanBuilder.makeLesson(title: "t", from: [Words.look, Words.see, Words.water], using: &random))
        #expect(plan.cards.first { $0.word == Words.look }?.alsoAccepted == ["见"])
        #expect(plan.cards.first { $0.word == Words.water }?.alsoAccepted == [])
    }
}

@Suite("Flash card grading")
struct FlashcardGraderTests {
    private func card(_ word: WordPair, _ direction: Answer.Direction, alsoAccepted: [String] = []) -> Flashcard {
        Flashcard(word: word, direction: direction, format: .typed, alsoAccepted: alsoAccepted)
    }

    @Test("English is matched against any meaning or part of one, ignoring case, punctuation, asides and a leading to or the", arguments: [
        ("water", Words.water, true), ("Water.", Words.water, true), ("  WATER  ", Words.water, true),
        ("drink", Words.drink, true), ("To Drink!", Words.drink, true), ("to shout", Words.drink, true), ("shout", Words.drink, true),
        ("tell", Words.tell, true), ("inform", Words.tell, true), ("to tell, to inform", Words.tell, true),
        ("dad", Words.dad, true), ("father", Words.dad, true), ("coll", Words.dad, false),
        ("tea", Words.water, false), ("to", Words.drink, false),
    ])
    func english(answer: String, word: WordPair, isRight: Bool) {
        #expect(FlashcardGrader.isCorrect(answer, for: card(word, .chineseToEnglish)) == isRight)
    }

    @Test("one letter off is let through from five letters, and not below: tea one off is ten or sea")
    func typos() {
        let water = card(Words.water, .chineseToEnglish)
        #expect(FlashcardGrader.isCorrect("watr", for: water))
        #expect(FlashcardGrader.isCorrect("watter", for: water))
        #expect(FlashcardGrader.isCorrect("wafer", for: water))
        #expect(!FlashcardGrader.isCorrect("wtr", for: water))
        let tea = card(Words.tea, .chineseToEnglish)
        #expect(!FlashcardGrader.isCorrect("ten", for: tea))
        #expect(!FlashcardGrader.isCorrect("sea", for: tea))
    }

    @Test("a card showing English takes the Hanzi only; pinyin or English is turned away, not marked wrong")
    func hanziOnly() {
        let water = card(Words.water, .englishToChinese)
        #expect(FlashcardGrader.isCorrect("水", for: water))
        #expect(FlashcardGrader.isCorrect(" 水 ", for: water))
        #expect(!FlashcardGrader.canCheck("shui", for: water))
        #expect(!FlashcardGrader.canCheck("shuǐ", for: water))
        #expect(!FlashcardGrader.canCheck("水 water", for: water))
        #expect(!FlashcardGrader.isCorrect("茶", for: water))
        #expect(FlashcardGrader.canCheck("茶", for: water))
    }

    @Test("Hanzi typed into a card showing Chinese is turned away rather than graded")
    func noHanziForEnglish() {
        #expect(!FlashcardGrader.canCheck("水", for: card(Words.water, .chineseToEnglish)))
    }

    @Test("another word in the lesson with the same meaning is right, since the English alone cannot tell them apart")
    func sharedMeaning() {
        let look = card(Words.look, .englishToChinese, alsoAccepted: ["见"])
        #expect(FlashcardGrader.isCorrect("见", for: look))
        #expect(FlashcardGrader.isCorrect("看", for: look))
    }

    /// Cost: words are stored as simplified Hanzi, so the traditional form, right to a
    /// reader of it, is marked wrong.
    @Test("the traditional form is marked wrong")
    func traditionalIsWrong() {
        let book = card(Words.book, .englishToChinese)
        #expect(!FlashcardGrader.isCorrect("書", for: book))
    }

    /// Cost: only the word's own meanings count, so a synonym it does not list is wrong.
    @Test("an English synonym the word does not list is marked wrong")
    func unlistedSynonymIsWrong() {
        #expect(!FlashcardGrader.isCorrect("beverage", for: card(Words.drink, .chineseToEnglish)))
    }
}

@Suite("Flash card lessons")
struct FlashcardLessonTests {
    private func lesson(_ cards: [Flashcard]) -> FlashcardLesson {
        FlashcardLesson(plan: FlashcardPlan(title: "t", cards: cards))
    }

    private let typedWater = Flashcard(word: Words.water, direction: .englishToChinese, format: .typed)
    private let pickedTea = Flashcard(
        word: Words.tea, direction: .chineseToEnglish,
        format: .picked(options: [Words.book, Words.tea, Words.water, Words.dad])
    )

    @Test("a right answer is a clean solve and an answer, typed, in the card's direction")
    func typedRight() {
        var lesson = lesson([typedWater, pickedTea])
        #expect(lesson.submit(typed: "水") == true)
        #expect(lesson.phase == .answered(isCorrect: true, given: "水"))
        #expect(lesson.cleanSolvesByPairID == [Words.water.id: 1])
        #expect(lesson.answers == [
            Answer(wordID: Words.water.id, exercise: .flashcardTyped, direction: .englishToChinese, isCorrect: true, wrongAttempts: 0),
        ])
    }

    @Test("a wrong pick is a miss and an answer, picked, showing the option as it read")
    func pickedWrong() {
        var lesson = lesson([pickedTea])
        #expect(lesson.pick(Words.book) == false)
        #expect(lesson.phase == .answered(isCorrect: false, given: "book"))
        #expect(lesson.missesByPairID == [Words.tea.id: 1])
        #expect(lesson.answers.first?.exercise == .flashcardPicked)
        #expect(lesson.answers.first?.wrongAttempts == 1)
        #expect(lesson.missedPairs.map(\.pair) == [Words.tea])
    }

    @Test("one try: a second answer, an answer the card cannot take, or one it cannot check is ignored")
    func oneTry() {
        var lesson = lesson([typedWater, pickedTea])
        #expect(lesson.submit(typed: "shui") == nil)
        #expect(lesson.pick(Words.water) == nil)
        #expect(lesson.phase == .answering)
        lesson.submit(typed: "茶")
        #expect(lesson.submit(typed: "水") == nil)
        #expect(lesson.answers.count == 1)
    }

    @Test("it moves on only once a card is answered, and finishes after the last")
    func advancing() {
        var lesson = lesson([typedWater, pickedTea])
        lesson.advance()
        #expect(lesson.cardIndex == 0)
        lesson.submit(typed: "水")
        lesson.advance()
        #expect(lesson.cardIndex == 1)
        #expect(lesson.progress == 0.5)
        lesson.pick(Words.tea)
        lesson.advance()
        #expect(lesson.isFinished)
        #expect(lesson.progress == 1)
        #expect(lesson.clearedPairs == [Words.water, Words.tea])
    }

    @Test("don't know settles the card as a mistake with no tries, and only while it waits for an answer")
    func dontKnow() {
        var lesson = lesson([typedWater, pickedTea])
        #expect(lesson.skip() == false)
        #expect(lesson.phase == .answered(isCorrect: false, given: ""))
        #expect(lesson.missesByPairID == [Words.water.id: 1])
        #expect(lesson.answers.first?.wrongAttempts == 0)
        #expect(lesson.skip() == nil)
        #expect(lesson.submit(typed: "水") == nil)
        lesson.advance()
        #expect(lesson.cardIndex == 1)
    }

    @Test("a card closed on before it was answered is not counted")
    func closedEarly() {
        var lesson = lesson([typedWater, pickedTea])
        lesson.submit(typed: "水")
        lesson.advance()
        #expect(lesson.answers.map(\.wordID) == [Words.water.id])
    }
}
