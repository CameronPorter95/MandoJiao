import MatchingDomain
import SpeakingDomain

struct SettingsState: Equatable {
    var strictness: AnswerStrictness = .default
    var showsPinyin = false
    var matchingRounds = MatchingSettings.defaultRounds
    var speakingCardLimit = SpeakingSettings.defaultCardLimit
}

enum SettingsAction: Equatable {
    case appeared
    case strictnessChanged(AnswerStrictness)
    case showsPinyinChanged(Bool)
    case matchingRoundsChanged(Int)
    case speakingCardLimitChanged(Int)
}
