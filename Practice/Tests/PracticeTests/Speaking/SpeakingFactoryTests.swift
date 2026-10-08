import Foundation
import Testing
import CoreTestSupport
import LibraryDomain
import LibraryTestSupport
import PracticeDI
import PracticeDomain
import PracticeTestSupport
import PracticeUI

@Suite("Speaking lesson built to run headlessly")
@MainActor
struct SpeakingFactoryTests {
    @Test("a lesson runs to the end on scripted speech without waiting on the clock")
    func runsThrough() async throws {
        let repository = FakeVocabularyRepository()
        var attempts: [SpeechAttempt] = []
        let driver = SpeakingFactory.makeDriver(
            dependencies: try TestDependencies(),
            navigation: SpeakingNavigation(didClose: {}),
            input: SpeakingInput(
                request: LessonRequest(title: "t", pool: [WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")]),
                recordResults: RecordLessonResultsUseCase(repository: repository)
            ),
            recogniser: ScriptedRecogniser(transcripts: ["shui"]),
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
}
