import CoreDomain
import CoreSound
import OSLog
import SpeakingDI
import SwiftData
import SwiftUI
import VocabularyDI

@main
struct MandoJiaoApp: App {
    private let vocabulary: VocabularyFactory
    private let speaking: SpeakingFactory

    init() {
        // The matching lesson reaches for sound through MatchSounds so its logic stays
        // free of AVFoundation. This is the one place that decides what actually plays.
        MatchSounds.shared = ToneEngine.shared

        let errorLog = Logger(subsystem: "com.cameronporter.MandoJiao", category: "errors")
        ErrorLog.sink = { model, context in
            errorLog.notice(
                "\(context, privacy: .public) failed: \(model.domain, privacy: .public) \(model.code) \(model.description, privacy: .public)"
            )
        }

        do {
            let container = try VocabularyFactory.openStore()
            vocabulary = VocabularyFactory(
                container: container,
                minimumMatchingWords: MatchingPlanBuilder.pairsPerExercise,
                quickPracticeRounds: MatchingPlanBuilder.exercisesPerLesson
            )
            speaking = SpeakingFactory(recordResults: vocabulary.recordLessonResults)
        } catch {
            fatalError("Could not open the vocabulary store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(vocabulary: vocabulary, speaking: speaking)
        }
    }
}
