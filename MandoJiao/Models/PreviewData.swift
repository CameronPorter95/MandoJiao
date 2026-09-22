import Foundation
import SwiftData

/// In-memory container so previews have vocabulary without touching the real store.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: VocabWord.self, Deck.self,
            configurations: configuration
        )
        SampleVocabulary.seedIfNeeded(container.mainContext)
        return container
    }()
}
