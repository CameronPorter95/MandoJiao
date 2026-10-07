import DictionaryDomain
import Foundation
import SwiftData
import VocabularyDomain

/// The data layer's one entry point. Everything concrete behind it stays internal.
public enum VocabularyStore {
    /// Opens the store. One written by an earlier shape is migrated where SwiftData can infer
    /// how, and otherwise fails to open, as `VocabularySchemaV1` explains.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV1.self),
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

    /// Works out the strength of any word answered before strength was kept, by replaying its
    /// answers in order. A word with a strength already is left alone, so this runs once.
    @MainActor
    public static func rememberPastAnswers(_ container: ModelContainer) {
        let context = container.mainContext
        let unscored = #Predicate<VocabWord> { $0.lastAnsweredAt == nil }
        guard let words = try? context.fetch(FetchDescriptor(predicate: unscored)) else { return }
        var changed = false
        for word in words where !word.answers.isEmpty {
            for record in word.answers.sorted(by: { $0.answeredAt < $1.answeredAt }) {
                guard let answer = record.answer else { continue }
                word.memory = word.memory.answered(answer, at: record.answeredAt)
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Only touches an empty store, so it never fights the user's own edits.
    @MainActor
    /// `hskWords` is read only when the store is empty.
    public static func seedIfNeeded(_ container: ModelContainer, hskWords: () -> [HSKWord]) {
        let context = container.mainContext
        let existing = try? context.fetchCount(FetchDescriptor<VocabWord>())
        guard (existing ?? 0) == 0 else { return }

        // One time for everything seeded, so a date sort falls back to names; see BuiltInInstaller.
        let seededAt = Date.now
        let starter = Folder(name: SampleVocabulary.folderName)
        starter.builtInKey = SampleVocabulary.builtInKey
        context.insert(starter)
        for (position, plan) in SampleVocabulary.deckPlan.enumerated() {
            let words = plan.entries.map {
                VocabWord(english: $0.english, hanzi: $0.hanzi, pinyin: $0.pinyin)
            }
            words.forEach(context.insert)
            let deck = Deck(name: plan.name, words: words, folder: starter, position: position)
            deck.createdAt = seededAt
            deck.editedAt = seededAt
            context.insert(deck)
        }
        try? context.save()

        // A fresh install starts with HSK 1; the other levels are added from the library.
        let words = hskWords()
        if !words.isEmpty {
            try? BuiltInInstaller.install(HSK.plan(level: 1, words: words, topLevelFolders: 1), in: context)
        }
    }
}
