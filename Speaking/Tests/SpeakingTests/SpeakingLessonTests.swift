import Testing
import CoreDomain
import CoreTestSupport
import SpeakingTestSupport
import VocabularyTestSupport
@testable import SpeakingDomain
@testable import SpeakingData
@testable import SpeakingUI
import VocabularyDomain

@Suite("Speaking lesson attempts")
@MainActor
struct SpeakingLessonTests {
    private let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    private let phone = WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī")
    private let green = WordPair(english: "green", hanzi: "绿", pinyin: "lǜ")

    private func makeLesson(_ cards: [WordPair]? = nil) -> SpeakingLesson {
        SpeakingLesson(plan: SpeakingPlan(title: "t", cards: cards ?? [water, phone, green]))
    }

    @Test("a correct first attempt settles the card and clears one mistake")
    func rightFirstTime() {
        var lesson = makeLesson()
        lesson.submit("shui")

        #expect(lesson.phase == .correct(heard: "shui"))
        #expect(lesson.cleanSolvesByPairID[water.id] == 1)
        #expect(lesson.missesByPairID.isEmpty)
        #expect(lesson.failedAttempts == 0)
    }

    @Test("attempts count down and report how many are left")
    func attemptsCountDown() {
        var lesson = makeLesson()
        #expect(lesson.attemptsLeft == 3)

        lesson.submit("cha")
        #expect(lesson.phase == .wrong(heard: "cha", attemptsLeft: 2))

        lesson.submit("fan")
        #expect(lesson.phase == .wrong(heard: "fan", attemptsLeft: 1))
        #expect(lesson.attemptsLeft == 1)
    }

    @Test("winning on the third go still counts as knowing the word")
    func thirdAttemptStillCounts() {
        // Three attempts exist because recognition of isolated words is unreliable, so
        // spending them is not evidence the word is unknown.
        var lesson = makeLesson()
        lesson.submit("cha")
        lesson.submit("fan")
        lesson.submit("shui")

        #expect(lesson.phase == .correct(heard: "shui"))
        #expect(lesson.cleanSolvesByPairID[water.id] == 1)
        #expect(lesson.missesByPairID.isEmpty)
        // Still counted against accuracy, just not against the word.
        #expect(lesson.failedAttempts == 2)
    }

    @Test("three failures record exactly one mistake and reveal the answer")
    func exhaustion() {
        var lesson = makeLesson()
        lesson.submit("cha")
        lesson.submit("fan")
        lesson.submit("shu")

        #expect(lesson.phase == .exhausted(heard: "shu"))
        #expect(lesson.missesByPairID[water.id] == 1)
        #expect(lesson.cleanSolvesByPairID.isEmpty)
        #expect(lesson.attemptsLeft == 0)
        #expect(lesson.failedAttempts == 3)
    }

    @Test("a settled card ignores further answers")
    func settledCardIsInert() {
        var lesson = makeLesson()
        lesson.submit("cha")
        lesson.submit("fan")
        lesson.submit("shu")
        lesson.submit("shui")

        #expect(lesson.missesByPairID[water.id] == 1)
        #expect(lesson.cleanSolvesByPairID.isEmpty)
    }

    @Test("starting another attempt clears the last failure without spending a try")
    func beginAttemptClearsAFailure() {
        var lesson = makeLesson()
        lesson.submit("cha")
        #expect(lesson.phase == .wrong(heard: "cha", attemptsLeft: 2))

        lesson.beginAttempt()

        // Back to a blank card, so the next attempt's transcript has somewhere to show.
        #expect(lesson.phase == .idle)
        // Clearing the display is not a free go.
        #expect(lesson.attemptsLeft == 2)
        #expect(lesson.failedAttempts == 1)
    }

    @Test("a settled card keeps its verdict when another attempt is started")
    func beginAttemptLeavesSettledCardsAlone() {
        var correct = makeLesson()
        correct.submit("shui")
        correct.beginAttempt()
        #expect(correct.phase == .correct(heard: "shui"))

        var exhausted = makeLesson()
        exhausted.submit("x")
        exhausted.submit("x")
        exhausted.submit("x")
        exhausted.beginAttempt()
        #expect(exhausted.phase == .exhausted(heard: "x"))
    }

    @Test("clearing a failure does not lose the recorded mistake")
    func beginAttemptKeepsTheTally() {
        var lesson = makeLesson()
        lesson.submit("x")
        lesson.submit("x")
        lesson.beginAttempt()
        lesson.submit("x")

        #expect(lesson.phase == .exhausted(heard: "x"))
        #expect(lesson.missesByPairID[water.id] == 1)
        #expect(lesson.failedAttempts == 3)
    }

    @Test("advancing resets the card state")
    func advancing() {
        var lesson = makeLesson()
        lesson.submit("cha")
        lesson.submit("fan")
        lesson.submit("shu")
        lesson.advance()

        #expect(lesson.cardIndex == 1)
        #expect(lesson.phase == .idle)
        #expect(lesson.attemptsLeft == 3)
        #expect(!lesson.isFinished)
    }

    @Test("a solved card is flagged so the speaking lesson can keep listening into the next one")
    func advancingAfterCorrect() {
        var lesson = makeLesson()
        #expect(!lesson.advancedAfterCorrect, "nothing has been answered yet")

        lesson.submit("shui")
        lesson.advance()
        #expect(lesson.advancedAfterCorrect)
    }

    @Test("a card that ran out of attempts is not flagged, so the microphone stops")
    func advancingAfterExhaustion() {
        // Getting it wrong should leave the answer on screen to be read, not carry
        // straight on into the next word.
        var lesson = makeLesson()
        lesson.submit("x")
        lesson.submit("x")
        lesson.submit("x")
        lesson.advance()

        #expect(!lesson.advancedAfterCorrect)
    }

    @Test("the flag tracks the most recent card, not any earlier one")
    func flagIsNotSticky() {
        var lesson = makeLesson()
        lesson.submit("shui")
        lesson.advance()
        #expect(lesson.advancedAfterCorrect)

        lesson.submit("x")
        lesson.submit("x")
        lesson.submit("x")
        lesson.advance()
        #expect(!lesson.advancedAfterCorrect)
    }

    @Test("a speaking lesson finishes after its last card")
    func finishing() {
        var lesson = makeLesson()
        for answer in ["shui", "shouji", "lv"] {
            lesson.submit(answer)
            lesson.advance()
        }

        #expect(lesson.isFinished)
        #expect(lesson.progress == 1)
        #expect(lesson.cleanSolvesByPairID.count == 3)
    }

    @Test("a one-card speaking lesson runs and finishes")
    func singleCardLesson() {
        var lesson = makeLesson([water])
        lesson.submit("shui")
        lesson.advance()
        #expect(lesson.isFinished)
    }

    @Test("the review split separates failed words from cleared ones")
    func reviewSplit() {
        var lesson = makeLesson()
        lesson.submit("shui")
        lesson.advance()

        lesson.submit("x")
        lesson.submit("x")
        lesson.submit("x")
        lesson.advance()

        lesson.submit("lv")
        lesson.advance()

        #expect(lesson.missedPairs.map(\.pair.english) == ["mobile phone"])
        #expect(lesson.clearedPairs.map(\.english) == ["green", "water"])
    }

    @Test("advancing past the end changes nothing")
    func advancingAfterFinishing() {
        var lesson = makeLesson([water])
        lesson.submit("shui")
        lesson.advance()
        lesson.advance()

        #expect(lesson.isFinished)
        #expect(lesson.cardIndex == 0)
        #expect(lesson.cleanSolvesByPairID[water.id] == 1)
    }
}
