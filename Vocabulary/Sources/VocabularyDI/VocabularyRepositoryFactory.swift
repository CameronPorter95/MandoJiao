import CoreDI
import SwiftData
import VocabularyData
import VocabularyDomain

/// Builds the vocabulary graph.
///
/// In `VocabularyDI` because it is the only target allowed to reach `VocabularyData`. That
/// is what lets a caller outside the package, such as a lesson recording its results,
/// obtain a use case without ever seeing the store.
public enum VocabularyRepositoryFactory {
    /// Opens the store, migrating an older schema, and fills an empty one with starter words.
    @MainActor
    public static func openStore(inMemory: Bool = false) throws -> ModelContainer {
        let container = try VocabularyStore.makeContainer(inMemory: inMemory)
        VocabularyStore.seedIfNeeded(container)
        return container
    }

    @MainActor
    public static func makeRepository(dependencies: Dependencies) -> any VocabularyRepository {
        VocabularyStore.repository(for: dependencies.modelContainer)
    }

    public static func makeLexiconRepository() -> any LexiconRepository {
        Lexicon.repository
    }

    public static func makeDictionaryRepository() -> any DictionaryRepository {
        CEDICT.dictionary
    }

    public static func makeHSKRepository() -> any HSKRepository {
        HSKSource.repository
    }

    public static func makeLibraryLayoutRepository() -> any LibraryLayoutRepository {
        LibraryLayoutRepositoryImpl()
    }

    /// The seam other packages record results through, injected by the app.
    @MainActor
    public static func makeRecordLessonResultsUseCase(dependencies: Dependencies) -> RecordLessonResultsUseCase {
        RecordLessonResultsUseCase(repository: makeRepository(dependencies: dependencies))
    }
}
