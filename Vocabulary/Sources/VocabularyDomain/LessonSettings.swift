import Foundation

/// What every lesson drawn from the vocabulary follows, whichever exercise it is.
public nonisolated struct LessonSettings: Equatable, Sendable {
    /// Leaves words marked learnt out of a deck's, a folder's and quick practice's lessons.
    /// The mistakes list still drills them: a mistake is worth earning back either way.
    public var skipsLearntWords: Bool

    public init(skipsLearntWords: Bool) {
        self.skipsLearntWords = skipsLearntWords
    }

    public static let `default` = LessonSettings(skipsLearntWords: false)
}

/// Synchronous, because every setting is a local value.
public nonisolated protocol LessonSettingsRepository: Sendable {
    func settings() -> LessonSettings
    func setSkipsLearntWords(_ skips: Bool)
}

public nonisolated extension Array where Element == Word {
    /// The words a lesson may draw from these, under the settings.
    func forLessons(_ settings: LessonSettings) -> [Word] {
        settings.skipsLearntWords ? filter { !$0.isLearnt } : self
    }
}
