import Foundation
import Testing
@testable import SpeakingData
@testable import SpeakingDomain

@Suite("Speaking settings storage")
struct SpeakingSettingsTests {
    /// A private suite per test, so nothing touches the real settings.
    private let defaults = UserDefaults(suiteName: "SpeakingSettingsTests-\(UUID().uuidString)")!

    @Test("an empty store gives the defaults")
    func defaultsWhenUnset() {
        #expect(SpeakingSettingsRepositoryImpl(defaults: defaults).settings() == .default)
    }

    @Test("values saved before the move still load, under their original keys and raw values")
    func existingValuesLoad() {
        // What @AppStorage wrote before the settings repository existed.
        defaults.set("strict", forKey: "speechStrictness")
        defaults.set(12, forKey: "drillCardLimit")

        let settings = SpeakingSettingsRepositoryImpl(defaults: defaults).settings()
        #expect(settings == SpeakingSettings(strictness: .strict, cardLimit: 12))
    }

    @Test("saving writes the same keys and raw values")
    func savingUsesTheSameKeys() {
        let repository = SpeakingSettingsRepositoryImpl(defaults: defaults)
        repository.setStrictness(.lenient)
        repository.setCardLimit(30)

        #expect(defaults.string(forKey: "speechStrictness") == "lenient")
        #expect(defaults.integer(forKey: "drillCardLimit") == 30)
    }

    @Test("the card limit is kept inside its range")
    func cardLimitClamped() {
        let repository = SpeakingSettingsRepositoryImpl(defaults: defaults)
        let setLimit = SetSpeakingCardLimitUseCase(repository: repository)

        setLimit(1)
        #expect(repository.settings().cardLimit == SpeakingSettings.cardLimitRange.lowerBound)
        setLimit(500)
        #expect(repository.settings().cardLimit == SpeakingSettings.cardLimitRange.upperBound)
    }
}
