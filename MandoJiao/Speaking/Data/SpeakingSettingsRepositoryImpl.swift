import Foundation

/// Reads what the settings screen writes, under the same keys and raw values.
nonisolated struct SpeakingSettingsRepositoryImpl: SpeakingSettingsRepository {
    /// Documented as thread-safe, though not marked `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func settings() -> SpeakingSettings {
        let strictness = defaults.string(forKey: Preferences.Key.speechStrictness)
            .flatMap(AnswerStrictness.init(rawValue:)) ?? .default
        let cardLimit = defaults.object(forKey: Preferences.Key.speakingCardLimit) as? Int
            ?? SpeakingSettings.defaultCardLimit
        return SpeakingSettings(strictness: strictness, cardLimit: cardLimit)
    }
}
