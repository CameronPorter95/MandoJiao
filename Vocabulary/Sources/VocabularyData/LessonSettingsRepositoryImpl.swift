import CoreDomain
import Foundation
import VocabularyDomain

/// Reads and writes what the settings screen does, under the same key.
nonisolated struct LessonSettingsRepositoryImpl: LessonSettingsRepository {
    /// Documented as thread-safe, though not marked `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func settings() -> LessonSettings {
        LessonSettings(skipsLearntWords: defaults.bool(forKey: Preferences.Key.skipsLearntWords))
    }

    func setSkipsLearntWords(_ skips: Bool) {
        defaults.set(skips, forKey: Preferences.Key.skipsLearntWords)
    }
}

public nonisolated enum LessonSettingsStore {
    public static func repository() -> any LessonSettingsRepository { LessonSettingsRepositoryImpl() }
}
