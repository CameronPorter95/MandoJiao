import SwiftData
import SwiftUI

@main
struct MandoJiaoApp: App {
    private let container: ModelContainer

    init() {
        // The exercises reach for sound through MatchSounds so their logic stays free of
        // AVFoundation. This is the one place that decides what actually plays.
        MatchSounds.shared = ToneEngine.shared

        do {
            let container = try ModelContainer(for: VocabWord.self, Deck.self)
            SampleVocabulary.seedIfNeeded(container.mainContext)
            self.container = container
        } catch {
            fatalError("Could not open the vocabulary store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
