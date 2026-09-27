import CoreDomain
import Foundation
import MatchingDomain

/// Reads and writes what the settings screen does, under the same keys.
public nonisolated struct MatchingSettingsRepositoryImpl: MatchingSettingsRepository {
    /// Documented as thread-safe, though not marked `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func settings() -> MatchingSettings {
        MatchingSettings(
            showsPinyin: defaults.bool(forKey: Preferences.Key.showsPinyin),
            rounds: defaults.object(forKey: Preferences.Key.matchingRounds) as? Int ?? MatchingSettings.defaultRounds
        )
    }

    public func setShowsPinyin(_ showsPinyin: Bool) {
        defaults.set(showsPinyin, forKey: Preferences.Key.showsPinyin)
    }

    public func setRounds(_ rounds: Int) {
        defaults.set(rounds, forKey: Preferences.Key.matchingRounds)
    }
}
