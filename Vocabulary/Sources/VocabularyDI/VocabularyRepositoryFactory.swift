import CoreDI
import DictionaryDomain
import SwiftData
import VocabularyData
import VocabularyDomain

/// Builds the vocabulary graph.
///
/// In `VocabularyDI` because it is the only target allowed to reach `VocabularyData`. That
/// is what lets a caller outside the package, such as a lesson recording its results,
/// obtain a use case without ever seeing the store.
public enum VocabularyRepositoryFactory {
    /// Opens the store, migrating an older schema, and fills an empty one with starter words
    /// and HSK 1. `hskWords` is the dictionary's syllabus, read only when the store is empty.
    @MainActor
    public static func openStore(inMemory: Bool = false, hskWords: () -> [HSKWord]) throws -> ModelContainer {
        let container = try VocabularyStore.makeContainer(inMemory: inMemory)
        VocabularyStore.seedIfNeeded(container, hskWords: hskWords)
        VocabularyStore.rememberPastAnswers(container)
        return container
    }

    @MainActor
    public static func makeRepository(dependencies: Dependencies) -> any VocabularyRepository {
        VocabularyStore.repository(for: dependencies.modelContainer)
    }

    /// The library's words as the dictionary sees them, injected by the app.
    @MainActor
    public static func makeSavedReadingsRepository(dependencies: Dependencies) -> any SavedReadingsRepository {
        VocabularySavedReadings(repository: makeRepository(dependencies: dependencies))
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
