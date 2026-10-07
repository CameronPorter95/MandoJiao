import CoreDI
import VocabularyData
import VocabularyDomain

/// Hands out the lesson settings' use cases, so the settings screen, in another package,
/// can edit them without ever seeing `VocabularyData`.
public enum LessonSettingsFactory {
    @MainActor
    public static func makeGetSettingsUseCase(dependencies: Dependencies) -> GetLessonSettingsUseCase {
        GetLessonSettingsUseCase(repository: LessonSettingsStore.repository())
    }

    @MainActor
    public static func makeSetSkipsLearntWordsUseCase(dependencies: Dependencies) -> SetSkipsLearntWordsUseCase {
        SetSkipsLearntWordsUseCase(repository: LessonSettingsStore.repository())
    }
}
