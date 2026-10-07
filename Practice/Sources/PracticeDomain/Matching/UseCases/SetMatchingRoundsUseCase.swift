import Foundation

public nonisolated struct SetMatchingRoundsUseCase: Sendable {
    public let repository: any MatchingSettingsRepository

    public init(repository: any MatchingSettingsRepository) {
        self.repository = repository
    }

    /// Clamped to `MatchingSettings.roundsRange`.
    public func callAsFunction(_ rounds: Int) {
        let range = MatchingSettings.roundsRange
        repository.setRounds(min(max(rounds, range.lowerBound), range.upperBound))
    }
}
