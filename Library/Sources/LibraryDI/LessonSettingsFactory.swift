import CoreDI
import LibraryData
import LibraryDomain

/// Hands out the lesson settings' use cases, so the settings screen, in another package,
/// can edit them without ever seeing `LibraryData`.
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
