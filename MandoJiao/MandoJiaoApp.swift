import SwiftData
import SwiftUI

@main
struct MandoJiaoApp: App {
    private let container: ModelContainer

    init() {
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
