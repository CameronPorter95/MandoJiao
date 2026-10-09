import CoreTestSupport
import LibraryDomain
import PracticeDI
import ProgressDomain
import Testing
@testable import AppComposition

/// Pins what drifted when the app and mando each built their own inputs: today's plan's
/// read-aloud steps were left hearing the microphone under -scripted-speech.
@Suite("App composer")
@MainActor
struct AppComposerTests {
    private let request = LessonRequest(title: "t", pool: [WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")])
    private let plan = TodayPlan(theme: .newWords, title: "New words", synopsis: "Learn.", steps: [], source: nil, otherWords: [])

    @Test("scripted speech reaches every lesson that listens: a speaking lesson and today's plan")
    func speechReachesEveryListener() throws {
        let speech = ScriptedSpeech()
        let composer = AppComposer(dependencies: try TestDependencies(), speech: speech)

        #expect(composer.speakingInput(request).speech === speech)
        #expect(composer.todayPlanInput(plan).speech === speech)
    }

    @Test("without scripted speech, lessons hear the microphone")
    func noSpeech() throws {
        let composer = AppComposer(dependencies: try TestDependencies(), speech: nil)
        #expect(composer.speakingInput(request).speech == nil)
        #expect(composer.todayPlanInput(plan).speech == nil)
    }

    @Test("the library reaches dictionary pages as views and as drivers")
    func bothPageSeams() throws {
        let composer = AppComposer(dependencies: try TestDependencies(), speech: nil)
        #expect(composer.libraryInput.dictionary.pageDriver != nil)
    }
}
