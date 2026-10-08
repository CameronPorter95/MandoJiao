import Foundation
import Testing
import CoreTestSupport
import CoreUI
import LibraryDomain
import LibraryTestSupport
import PracticeDI
import PracticeDomain
import PracticeUI

@Suite("Speaking lesson built to run headlessly")
@MainActor
struct SpeakingFactoryTests {
    @Test("a lesson runs to the end on scripted speech without waiting on the clock")
    func runsThrough() async throws {
        let repository = FakeVocabularyRepository()
        let speech = ScriptedSpeech()
        speech.enqueue("shui")
        var attempts: [SpeechAttempt] = []
        let driver = SpeakingFactory.makeDriver(
            dependencies: try TestDependencies(),
            navigation: SpeakingNavigation(didClose: {}),
            input: SpeakingInput(
                request: LessonRequest(title: "t", pool: [WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")]),
                recordResults: RecordLessonResultsUseCase(repository: repository)
            ),
            speech: speech,
            logAttempt: { attempts.append($0) }
        )
        let started = ContinuousClock.now

        try driver.send("appeared", nil)
        #expect(await waitUntil { driver.summary().hasPrefix("speaking  card 1/1") })
        try driver.send("startListeningTapped", nil)

        #expect(await waitUntil { driver.summary().hasPrefix("speaking  finished") })
        // The device path settles after 700ms of stillness, and gives up after 5s.
        #expect(ContinuousClock.now - started < .seconds(1))
        #expect(attempts.map(\.wasCorrect) == [true])
        #expect(await waitUntil { await repository.recordedResults.count == 1 })
    }

    @Test("saying each answer as its card shows runs the lesson, the listen between them idle")
    func sayingCardByCard() async throws {
        let lesson = TwoCardLesson()
        try await lesson.start()

        try lesson.say(lesson.answerForShownCard())
        #expect(await waitUntil { lesson.driver.summary().hasPrefix("speaking  card 2/2") })
        await settle()
        #expect(lesson.driver.summary().contains("mic: idle  idle"))

        try lesson.say(lesson.answerForShownCard())
        #expect(await waitUntil { lesson.driver.summary().hasPrefix("speaking  finished") })
        #expect(lesson.attempts.map(\.wasCorrect) == [true, true])
    }

    @Test("an answer queued ahead is heard by the listen after a right answer")
    func queuedAheadCarriesOn() async throws {
        let lesson = TwoCardLesson()
        try await lesson.start()
        let first = lesson.answerForShownCard()
        lesson.speech.enqueue(first)
        lesson.speech.enqueue(first == "shui" ? "shouji" : "shui")

        try lesson.driver.send("startListeningTapped", nil)

        #expect(await waitUntil { lesson.driver.summary().hasPrefix("speaking  finished") })
        #expect(lesson.attempts.map(\.wasCorrect) == [true, true])
    }
}

@MainActor
private final class TwoCardLesson {
    let speech = ScriptedSpeech()
    var attempts: [SpeechAttempt] = []
    private(set) var driver: ScreenDriver!

    private let answers = ["水": "shui", "手机": "shouji"]

    init() {
        driver = SpeakingFactory.makeDriver(
            dependencies: try! TestDependencies(),
            navigation: SpeakingNavigation(didClose: {}),
            input: SpeakingInput(
                request: LessonRequest(title: "t", pool: [
                    WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
                    WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī"),
                ]),
                recordResults: RecordLessonResultsUseCase(repository: FakeVocabularyRepository())
            ),
            speech: speech,
            logAttempt: { [unowned self] in attempts.append($0) }
        )
    }

    func start() async throws {
        try driver.send("appeared", nil)
        _ = await waitUntil { self.driver.summary().hasPrefix("speaking  card 1/2") }
    }

    /// The summary reads `speaking  card 1/2  水  …`, so the Hanzi is its third part.
    func answerForShownCard() -> String {
        let hanzi = driver.summary().components(separatedBy: "  ")[2]
        return answers[hanzi] ?? ""
    }

    /// What the CLI's `say` does: queue the answer, then tap the microphone.
    func say(_ answer: String) throws {
        speech.enqueue(answer)
        try driver.send("startListeningTapped", nil)
    }
}
