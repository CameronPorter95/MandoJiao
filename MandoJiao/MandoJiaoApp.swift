import CoreDomain
import CoreSound
import OSLog
import SwiftData
import SwiftUI
import VocabularyDI

@main
struct MandoJiaoApp: App {
    private let dependencies: LiveDependencies

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
            dependencies = LiveDependencies(modelContainer: try VocabularyRepositoryFactory.openStore())
        } catch {
            fatalError("Could not open the vocabulary store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}
