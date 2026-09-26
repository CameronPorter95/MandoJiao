import Foundation
import Testing
@testable import MatchingData
@testable import MatchingDomain

@Suite("Matching settings storage")
struct MatchingSettingsTests {
    /// A private suite per test, so nothing touches the real settings.
    private let defaults = UserDefaults(suiteName: "MatchingSettingsTests-\(UUID().uuidString)")!

    @Test("an empty store gives the defaults")
    func defaultsWhenUnset() {
        #expect(MatchingSettingsRepositoryImpl(defaults: defaults).settings() == .default)
    }

    @Test("values saved before the move still load, under their original keys")
    func existingValuesLoad() {
        // What @AppStorage wrote before the settings repository existed.
        defaults.set(true, forKey: "showsPinyinInLessons")
        defaults.set(7, forKey: "matchingRoundsPerLesson")

        let settings = MatchingSettingsRepositoryImpl(defaults: defaults).settings()
        #expect(settings == MatchingSettings(showsPinyin: true, rounds: 7))
    }

    @Test("saving writes the same keys")
    func savingUsesTheSameKeys() {
        let repository = MatchingSettingsRepositoryImpl(defaults: defaults)
        repository.setShowsPinyin(true)
        repository.setRounds(15)

        #expect(defaults.bool(forKey: "showsPinyinInLessons"))
        #expect(defaults.integer(forKey: "matchingRoundsPerLesson") == 15)
    }

    @Test("the round count is kept inside its range")
    func roundsClamped() {
        let repository = MatchingSettingsRepositoryImpl(defaults: defaults)
        let setRounds = SetMatchingRoundsUseCase(repository: repository)

        setRounds(0)
        #expect(repository.settings().rounds == MatchingSettings.roundsRange.lowerBound)
        setRounds(99)
        #expect(repository.settings().rounds == MatchingSettings.roundsRange.upperBound)
    }
}
