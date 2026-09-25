import Foundation

/// Reads what the settings screen writes, under the same keys and raw values.
nonisolated struct DrillSettingsRepositoryImpl: DrillSettingsRepository {
    /// Documented as thread-safe, though not marked `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func settings() -> DrillSettings {
        let strictness = defaults.string(forKey: Preferences.Key.speechStrictness)
            .flatMap(MatchStrictness.init(rawValue:)) ?? .default
        let cardLimit = defaults.object(forKey: Preferences.Key.drillCardLimit) as? Int
            ?? DrillSettings.defaultCardLimit
        return DrillSettings(strictness: strictness, cardLimit: cardLimit)
    }
}
