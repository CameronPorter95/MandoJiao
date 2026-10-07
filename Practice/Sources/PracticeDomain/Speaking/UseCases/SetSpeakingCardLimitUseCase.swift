import Foundation

public nonisolated struct SetSpeakingCardLimitUseCase: Sendable {
    public let repository: any SpeakingSettingsRepository

    public init(repository: any SpeakingSettingsRepository) {
        self.repository = repository
    }

    /// Clamped to `SpeakingSettings.cardLimitRange`.
    public func callAsFunction(_ cardLimit: Int) {
        let range = SpeakingSettings.cardLimitRange
        repository.setCardLimit(min(max(cardLimit, range.lowerBound), range.upperBound))
    }
}
