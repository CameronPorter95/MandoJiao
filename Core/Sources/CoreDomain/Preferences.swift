import Foundation

/// One place for the `@AppStorage` keys, so a screen reading a setting and a screen
/// writing it cannot drift apart. Changing a key strands every saved value under it.
///
/// In Core rather than split per feature, because the settings screen writes what the
/// speaking and matching lessons read, and one registry is what keeps them agreeing.
public nonisolated enum Preferences {
    public enum Key {
        public static let speechStrictness = "speechStrictness"
        public static let showsPinyin = "showsPinyinInLessons"
        public static let matchingRounds = "matchingRoundsPerLesson"
        public static let speakingCardLimit = "drillCardLimit"
        public static let libraryLayout = "libraryLayout"
        public static let skipsLearntWords = "skipsLearntWords"
    }
}
