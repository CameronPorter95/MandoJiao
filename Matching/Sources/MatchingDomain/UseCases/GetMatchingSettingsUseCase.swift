import Foundation

public nonisolated struct GetMatchingSettingsUseCase: Sendable {
    public let repository: any MatchingSettingsRepository

    public init(repository: any MatchingSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> MatchingSettings {
        repository.settings()
    }
}
