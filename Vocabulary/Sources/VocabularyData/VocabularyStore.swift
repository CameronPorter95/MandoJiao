import Foundation
import SwiftData
import VocabularyDomain

/// The data layer's one entry point. Everything concrete behind it stays internal.
public enum VocabularyStore {
    /// Opens the store, migrating an older schema if there is one.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV3.self),
            migrationPlan: VocabularyMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    /// One repository per store, however many screens ask. Each screen's subscription is
    /// held by the repository it subscribed through, so a write through a second instance
    /// would never reach it: the word editor would save and the library would not update.
    @MainActor
    public static func repository(for container: ModelContainer) -> any VocabularyRepository {
        repositories.removeAll { $0.container == nil }
        if let shared = repositories.first(where: { $0.container === container }) {
            return shared.repository
        }
        let repository = VocabularyRepositoryImpl(localSource: VocabularyLocalSourceImpl(modelContainer: container))
        repositories.append(SharedRepository(container: container, repository: repository))
        return repository
    }

    @MainActor private static var repositories: [SharedRepository] = []

    /// Weak, so a test's in-memory store and its repository go when the test does.
    private struct SharedRepository {
        weak var container: ModelContainer?
        let repository: any VocabularyRepository
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
