import Foundation

public nonisolated struct SpeakingSettings: Equatable, Sendable {
    public static let defaultCardLimit = 20
    public static let `default` = SpeakingSettings(strictness: .default, cardLimit: defaultCardLimit)

    public var strictness: AnswerStrictness
    public var cardLimit: Int

    public init(strictness: AnswerStrictness, cardLimit: Int) {
        self.strictness = strictness
        self.cardLimit = cardLimit
    }
}

/// Synchronous, because every setting is a local value read when a speaking lesson starts.
public nonisolated protocol SpeakingSettingsRepository: Sendable {
    func settings() -> SpeakingSettings
}

public nonisolated struct GetSpeakingSettingsUseCase: Sendable {
    public let repository: any SpeakingSettingsRepository

    public init(repository: any SpeakingSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> SpeakingSettings {
        repository.settings()
    }
}
