import Foundation
import MatchingDomain
import VocabularyDomain
@testable import SettingsUI
import SpeakingDomain
import Testing

@Suite("Settings screen")
@MainActor
struct SettingsViewModelTests {
    private let speaking = InMemorySpeakingSettings(SpeakingSettings(strictness: .strict, cardLimit: 12))
    private let matching = InMemoryMatchingSettings(MatchingSettings(showsPinyin: true, rounds: 7))
    private let lessons = InMemoryLessonSettings(LessonSettings(skipsLearntWords: true))

    private func makeSettings() -> SettingsViewModel {
        SettingsViewModel(
            getSpeakingSettings: GetSpeakingSettingsUseCase(repository: speaking),
            setStrictness: SetAnswerStrictnessUseCase(repository: speaking),
            setSpeakingCardLimit: SetSpeakingCardLimitUseCase(repository: speaking),
            getMatchingSettings: GetMatchingSettingsUseCase(repository: matching),
            setShowsPinyin: SetShowsPinyinUseCase(repository: matching),
            setMatchingRounds: SetMatchingRoundsUseCase(repository: matching),
            getLessonSettings: GetLessonSettingsUseCase(repository: lessons),
            setSkipsLearntWords: SetSkipsLearntWordsUseCase(repository: lessons)
        )
    }

    @Test("appearing shows what the lessons have saved")
    func loading() {
        let settings = makeSettings()
        settings.send(.appeared)

        #expect(settings.state == SettingsState(strictness: .strict, showsPinyin: true, matchingRounds: 7, speakingCardLimit: 12, skipsLearntWords: true))
    }

    @Test("each change is saved to the lesson that owns it")
    func saving() {
        let settings = makeSettings()
        settings.send(.appeared)

        settings.send(.strictnessChanged(.lenient))
        settings.send(.speakingCardLimitChanged(30))
        settings.send(.showsPinyinChanged(false))
        settings.send(.matchingRoundsChanged(15))

        #expect(speaking.value == SpeakingSettings(strictness: .lenient, cardLimit: 30))
        #expect(matching.value == MatchingSettings(showsPinyin: false, rounds: 15))
        #expect(settings.state == SettingsState(strictness: .lenient, showsPinyin: false, matchingRounds: 15, speakingCardLimit: 30, skipsLearntWords: true))
    }

    @Test("a value outside its range shows as the value actually saved")
    func clamped() {
        let settings = makeSettings()
        settings.send(.appeared)

        settings.send(.matchingRoundsChanged(99))

        #expect(settings.state.matchingRounds == MatchingSettings.roundsRange.upperBound)
    }

    @Test("a change made elsewhere shows on return")
    func reappearing() {
        // The pinyin button in a matching lesson writes the same setting.
        let settings = makeSettings()
        settings.send(.appeared)
        matching.setShowsPinyin(false)

        settings.send(.appeared)

        #expect(!settings.state.showsPinyin)
    }

    @Test("skip learnt words shows what is saved, and saves a change at once")
    func skipsLearntWords() {
        let settings = makeSettings()
        settings.send(.appeared)
        #expect(settings.state.skipsLearntWords)
        settings.send(.skipsLearntWordsChanged(false))
        #expect(!settings.state.skipsLearntWords)
        #expect(!lessons.value.skipsLearntWords)
    }
}

private final class InMemoryLessonSettings: LessonSettingsRepository, @unchecked Sendable {
    var value: LessonSettings
    init(_ value: LessonSettings) { self.value = value }

    func settings() -> LessonSettings { value }
    func setSkipsLearntWords(_ skips: Bool) { value.skipsLearntWords = skips }
}

private final class InMemorySpeakingSettings: SpeakingSettingsRepository, @unchecked Sendable {
    var value: SpeakingSettings
    init(_ value: SpeakingSettings) { self.value = value }

    func settings() -> SpeakingSettings { value }
    func setStrictness(_ strictness: AnswerStrictness) { value.strictness = strictness }
    func setCardLimit(_ cardLimit: Int) { value.cardLimit = cardLimit }
}

private final class InMemoryMatchingSettings: MatchingSettingsRepository, @unchecked Sendable {
    var value: MatchingSettings
    init(_ value: MatchingSettings) { self.value = value }

    func settings() -> MatchingSettings { value }
    func setShowsPinyin(_ showsPinyin: Bool) { value.showsPinyin = showsPinyin }
    func setRounds(_ rounds: Int) { value.rounds = rounds }
}
