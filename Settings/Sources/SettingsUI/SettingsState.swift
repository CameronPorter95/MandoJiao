import PracticeDomain

struct SettingsState: Equatable {
    var strictness: AnswerStrictness = .default
    var showsPinyin = false
    var matchingRounds = MatchingSettings.defaultRounds
    var speakingCardLimit = SpeakingSettings.defaultCardLimit
    var skipsLearntWords = false
}

enum SettingsAction: Equatable {
    case appeared
    case strictnessChanged(AnswerStrictness)
    case showsPinyinChanged(Bool)
    case matchingRoundsChanged(Int)
    case speakingCardLimitChanged(Int)
    case skipsLearntWordsChanged(Bool)
}
