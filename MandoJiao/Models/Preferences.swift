import Foundation

/// One place for the `@AppStorage` keys and their defaults, so a screen reading a setting
/// and a screen writing it cannot drift apart on either.
enum Preferences {
    enum Key {
        static let speechStrictness = "speechStrictness"
        static let showsPinyin = "showsPinyinInLessons"
        static let matchingRounds = "matchingRoundsPerLesson"
        static let drillCardLimit = "drillCardLimit"
    }

    static let matchingRoundsRange = 5...20
    static let drillCardLimitRange = 5...40

    static var strictness: MatchStrictness {
        let raw = UserDefaults.standard.string(forKey: Key.speechStrictness)
        return raw.flatMap(MatchStrictness.init(rawValue:)) ?? .default
    }
}
