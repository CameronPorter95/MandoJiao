import MatchingDomain
import SpeakingDomain

/// The settings belong to the speaking and matching lessons, which this package cannot
/// reach past their domains, so the app hands their use cases in.
public struct SettingsInput {
    public let getSpeakingSettings: GetSpeakingSettingsUseCase
    public let setStrictness: SetAnswerStrictnessUseCase
    public let setSpeakingCardLimit: SetSpeakingCardLimitUseCase
    public let getMatchingSettings: GetMatchingSettingsUseCase
    public let setShowsPinyin: SetShowsPinyinUseCase
    public let setMatchingRounds: SetMatchingRoundsUseCase

    public init(
        getSpeakingSettings: GetSpeakingSettingsUseCase,
        setStrictness: SetAnswerStrictnessUseCase,
        setSpeakingCardLimit: SetSpeakingCardLimitUseCase,
        getMatchingSettings: GetMatchingSettingsUseCase,
        setShowsPinyin: SetShowsPinyinUseCase,
        setMatchingRounds: SetMatchingRoundsUseCase
    ) {
        self.getSpeakingSettings = getSpeakingSettings
        self.setStrictness = setStrictness
        self.setSpeakingCardLimit = setSpeakingCardLimit
        self.getMatchingSettings = getMatchingSettings
        self.setShowsPinyin = setShowsPinyin
        self.setMatchingRounds = setMatchingRounds
    }
}
