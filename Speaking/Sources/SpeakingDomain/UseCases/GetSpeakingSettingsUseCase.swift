import Foundation

public nonisolated struct GetSpeakingSettingsUseCase: Sendable {
    public let repository: any SpeakingSettingsRepository

    public init(repository: any SpeakingSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> SpeakingSettings {
        repository.settings()
    }
}
