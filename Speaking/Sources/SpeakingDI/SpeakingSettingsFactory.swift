import CoreDI
import SpeakingData
import SpeakingDomain

/// Hands out the speaking settings use cases, so the settings screen, in another
/// package, can edit them without ever seeing `SpeakingData`.
public enum SpeakingSettingsFactory {
    @MainActor
    public static func makeRepository(dependencies: Dependencies) -> any SpeakingSettingsRepository {
        SpeakingSettingsRepositoryImpl()
    }

    @MainActor
    public static func makeGetSettingsUseCase(dependencies: Dependencies) -> GetSpeakingSettingsUseCase {
        GetSpeakingSettingsUseCase(repository: makeRepository(dependencies: dependencies))
    }

    @MainActor
    public static func makeSetStrictnessUseCase(dependencies: Dependencies) -> SetAnswerStrictnessUseCase {
        SetAnswerStrictnessUseCase(repository: makeRepository(dependencies: dependencies))
    }

    @MainActor
    public static func makeSetCardLimitUseCase(dependencies: Dependencies) -> SetSpeakingCardLimitUseCase {
        SetSpeakingCardLimitUseCase(repository: makeRepository(dependencies: dependencies))
    }
}
