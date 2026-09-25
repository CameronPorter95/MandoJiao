import Foundation

/// One place for the `@AppStorage` keys, so a screen reading a setting and a screen
/// writing it cannot drift apart. Changing a key strands every saved value under it.
nonisolated enum Preferences {
    enum Key {
        static let speechStrictness = "speechStrictness"
        static let showsPinyin = "showsPinyinInLessons"
        static let matchingRounds = "matchingRoundsPerLesson"
        static let speakingCardLimit = "drillCardLimit"
    }

    static let matchingRoundsRange = 5...20
    static let speakingCardLimitRange = 5...40
}
