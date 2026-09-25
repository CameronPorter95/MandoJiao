import Foundation
import SwiftData
import VocabularyDomain

/// The data layer's one entry point. Everything concrete behind it stays internal.
public enum VocabularyStore {
    /// Opens the store, migrating an older schema if there is one.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV2.self),
            migrationPlan: VocabularyMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    public static func makeRepository(container: ModelContainer) -> any VocabularyRepository {
        VocabularyRepositoryImpl(localSource: VocabularyLocalSourceImpl(modelContainer: container))
    }

    /// Only touches an empty store, so it never fights the user's own edits.
    @MainActor
    public static func seedIfNeeded(_ container: ModelContainer) {
        let context = container.mainContext
        let existing = try? context.fetchCount(FetchDescriptor<VocabWord>())
        guard (existing ?? 0) == 0 else { return }

        for plan in SampleVocabulary.deckPlan {
            let words = plan.entries.map {
                VocabWord(english: $0.english, hanzi: $0.hanzi, pinyin: $0.pinyin)
            }
            words.forEach(context.insert)
            context.insert(Deck(name: plan.name, words: words))
        }

        try? context.save()
    }
}
