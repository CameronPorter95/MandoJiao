import CoreDomain
import Foundation
import SpeakingDomain

/// Reads what the settings screen writes, under the same keys and raw values.
public nonisolated struct SpeakingSettingsRepositoryImpl: SpeakingSettingsRepository {
    /// Documented as thread-safe, though not marked `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func settings() -> SpeakingSettings {
        let strictness = defaults.string(forKey: Preferences.Key.speechStrictness)
            .flatMap(AnswerStrictness.init(rawValue:)) ?? .default
        let cardLimit = defaults.object(forKey: Preferences.Key.speakingCardLimit) as? Int
            ?? SpeakingSettings.defaultCardLimit
        return SpeakingSettings(strictness: strictness, cardLimit: cardLimit)
    }

    /// The raw value is what is stored, so titles can be reworded freely.
    public func setStrictness(_ strictness: AnswerStrictness) {
        defaults.set(strictness.rawValue, forKey: Preferences.Key.speechStrictness)
    }

    public func setCardLimit(_ cardLimit: Int) {
        defaults.set(cardLimit, forKey: Preferences.Key.speakingCardLimit)
    }
}
