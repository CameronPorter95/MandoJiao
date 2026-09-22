import Testing
@testable import MandoJiao

@Suite("Speech drill attempts")
@MainActor
struct SpeakSessionTests {
    private let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    private let phone = WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī")
    private let green = WordPair(english: "green", hanzi: "绿", pinyin: "lǜ")

    private func makeSession(_ cards: [WordPair]? = nil) -> SpeakSession {
        SpeakSession(
            plan: SpeakPlan(title: "t", cards: cards ?? [water, phone, green]),
            sounds: SilentSounds()
        )
    }

    @Test("a correct first attempt settles the card and clears one mistake")
    func rightFirstTime() {
        let session = makeSession()
        session.submit("shui")

        #expect(session.phase == .correct(heard: "shui"))
        #expect(session.cleanSolvesByPairID[water.id] == 1)
        #expect(session.missesByPairID.isEmpty)
        #expect(session.failedAttempts == 0)
    }

    @Test("attempts count down and report how many are left")
    func attemptsCountDown() {
        let session = makeSession()
        #expect(session.attemptsLeft == 3)

        session.submit("cha")
        #expect(session.phase == .wrong(heard: "cha", attemptsLeft: 2))

        session.submit("fan")
        #expect(session.phase == .wrong(heard: "fan", attemptsLeft: 1))
        #expect(session.attemptsLeft == 1)
    }

    @Test("winning on the third go still counts as knowing the word")
    func thirdAttemptStillCounts() {
        // Three attempts exist because recognition of isolated words is unreliable, so
        // spending them is not evidence the word is unknown.
        let session = makeSession()
        session.submit("cha")
        session.submit("fan")
        session.submit("shui")

        #expect(session.phase == .correct(heard: "shui"))
        #expect(session.cleanSolvesByPairID[water.id] == 1)
        #expect(session.missesByPairID.isEmpty)
        // Still counted against accuracy, just not against the word.
        #expect(session.failedAttempts == 2)
    }

    @Test("three failures record exactly one mistake and reveal the answer")
    func exhaustion() {
        let session = makeSession()
        session.submit("cha")
        session.submit("fan")
        session.submit("shu")

        #expect(session.phase == .exhausted(heard: "shu"))
        #expect(session.missesByPairID[water.id] == 1)
        #expect(session.cleanSolvesByPairID.isEmpty)
        #expect(session.attemptsLeft == 0)
        #expect(session.failedAttempts == 3)
    }

    @Test("a settled card ignores further answers")
    func settledCardIsInert() {
        let session = makeSession()
        session.submit("cha")
        session.submit("fan")
        session.submit("shu")
        session.submit("shui")

        #expect(session.missesByPairID[water.id] == 1)
        #expect(session.cleanSolvesByPairID.isEmpty)
    }

    @Test("advancing resets the card state")
    func advancing() {
        let session = makeSession()
        session.submit("cha")
        session.submit("fan")
        session.submit("shu")
        session.advance()

        #expect(session.cardIndex == 1)
        #expect(session.phase == .idle)
        #expect(session.attemptsLeft == 3)
        #expect(!session.isFinished)
    }

    @Test("a drill finishes after its last card")
    func finishing() {
        let session = makeSession()
        for answer in ["shui", "shouji", "lv"] {
            session.submit(answer)
            session.advance()
        }

        #expect(session.isFinished)
        #expect(session.progress == 1)
        #expect(session.cleanSolvesByPairID.count == 3)
    }

    @Test("a one-card drill runs and finishes")
    func singleCardDrill() {
        let session = makeSession([water])
        session.submit("shui")
        session.advance()
        #expect(session.isFinished)
    }

    @Test("the review split separates failed words from cleared ones")
    func reviewSplit() {
        let session = makeSession()
        session.submit("shui")
        session.advance()

        session.submit("x")
        session.submit("x")
        session.submit("x")
        session.advance()

        session.submit("lv")
        session.advance()

        #expect(session.missedPairs.map(\.pair.english) == ["mobile phone"])
        #expect(session.clearedPairs.map(\.english) == ["green", "water"])
    }

    @Test("advancing by hand cannot be doubled by the pending auto-advance")
    func manualAdvanceCancelsTheScheduledOne() async {
        let session = makeSession()
        session.submit("shui")    // correct, so an auto-advance is queued
        session.advance()         // the continue path, arriving first
        #expect(session.cardIndex == 1)

        // Longer than the auto-advance delay: if it were still pending it would land here.
        try? await Task.sleep(for: .milliseconds(1200))
        #expect(session.cardIndex == 1)
    }
}
