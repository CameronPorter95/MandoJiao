import CoreDI
import PracticeData
import PracticeDomain

/// Hands out the matching settings use cases, so the settings screen and the home
/// screen, in other packages, can use them without ever seeing `MatchingData`.
public enum MatchingSettingsFactory {
    @MainActor
    public static func makeRepository(dependencies: Dependencies) -> any MatchingSettingsRepository {
        MatchingSettingsRepositoryImpl()
    }

    @MainActor
    public static func makeGetSettingsUseCase(dependencies: Dependencies) -> GetMatchingSettingsUseCase {
        GetMatchingSettingsUseCase(repository: makeRepository(dependencies: dependencies))
    }

    @MainActor
    public static func makeSetShowsPinyinUseCase(dependencies: Dependencies) -> SetShowsPinyinUseCase {
        SetShowsPinyinUseCase(repository: makeRepository(dependencies: dependencies))
    }

    @MainActor
    public static func makeSetRoundsUseCase(dependencies: Dependencies) -> SetMatchingRoundsUseCase {
        SetMatchingRoundsUseCase(repository: makeRepository(dependencies: dependencies))
    }
}
