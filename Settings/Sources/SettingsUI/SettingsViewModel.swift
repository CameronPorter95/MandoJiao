import PracticeDomain
import Observation
import VocabularyDomain

/// Every setting is owned by the lesson that reads it; this screen only edits them.
@MainActor
@Observable
public final class SettingsViewModel {
    private(set) var state = SettingsState()

    private let getSpeakingSettings: GetSpeakingSettingsUseCase
    private let setStrictness: SetAnswerStrictnessUseCase
    private let setSpeakingCardLimit: SetSpeakingCardLimitUseCase
    private let getMatchingSettings: GetMatchingSettingsUseCase
    private let setShowsPinyin: SetShowsPinyinUseCase
    private let setMatchingRounds: SetMatchingRoundsUseCase
    private let getLessonSettings: GetLessonSettingsUseCase
    private let setSkipsLearntWords: SetSkipsLearntWordsUseCase

    public init(
        getSpeakingSettings: GetSpeakingSettingsUseCase,
        setStrictness: SetAnswerStrictnessUseCase,
        setSpeakingCardLimit: SetSpeakingCardLimitUseCase,
        getMatchingSettings: GetMatchingSettingsUseCase,
        setShowsPinyin: SetShowsPinyinUseCase,
        setMatchingRounds: SetMatchingRoundsUseCase,
        getLessonSettings: GetLessonSettingsUseCase,
        setSkipsLearntWords: SetSkipsLearntWordsUseCase
    ) {
        self.getSpeakingSettings = getSpeakingSettings
        self.setStrictness = setStrictness
        self.setSpeakingCardLimit = setSpeakingCardLimit
        self.getMatchingSettings = getMatchingSettings
        self.setShowsPinyin = setShowsPinyin
        self.setMatchingRounds = setMatchingRounds
        self.getLessonSettings = getLessonSettings
        self.setSkipsLearntWords = setSkipsLearntWords
    }

    func send(_ action: SettingsAction) {
        switch action {
        case .appeared:
            // On every appearance, since a lesson's pinyin button changes a setting too.
            let speaking = getSpeakingSettings()
            let matching = getMatchingSettings()
            state = SettingsState(
                strictness: speaking.strictness,
                showsPinyin: matching.showsPinyin,
                matchingRounds: matching.rounds,
                speakingCardLimit: speaking.cardLimit,
                skipsLearntWords: getLessonSettings().skipsLearntWords
            )

        case .strictnessChanged(let strictness):
            state.strictness = strictness
            setStrictness(strictness)

        case .showsPinyinChanged(let showsPinyin):
            state.showsPinyin = showsPinyin
            setShowsPinyin(showsPinyin)

        case .matchingRoundsChanged(let rounds):
            setMatchingRounds(rounds)
            state.matchingRounds = getMatchingSettings().rounds

        case .speakingCardLimitChanged(let cardLimit):
            setSpeakingCardLimit(cardLimit)
            state.speakingCardLimit = getSpeakingSettings().cardLimit

        case .skipsLearntWordsChanged(let skips):
            state.skipsLearntWords = skips
            setSkipsLearntWords(skips)
        }
    }
}
