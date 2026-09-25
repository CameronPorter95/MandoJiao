import Foundation

nonisolated struct SpeakingSettings: Equatable, Sendable {
    static let defaultCardLimit = 20
    static let `default` = SpeakingSettings(strictness: .default, cardLimit: defaultCardLimit)

    var strictness: AnswerStrictness
    var cardLimit: Int
}

/// Synchronous, because every setting is a local value read when a speaking lesson starts.
nonisolated protocol SpeakingSettingsRepository: Sendable {
    func settings() -> SpeakingSettings
}

nonisolated struct GetSpeakingSettingsUseCase: Sendable {
    let repository: any SpeakingSettingsRepository

    func callAsFunction() -> SpeakingSettings {
        repository.settings()
    }
}
