import Foundation

public nonisolated struct SetAnswerStrictnessUseCase: Sendable {
    public let repository: any SpeakingSettingsRepository

    public init(repository: any SpeakingSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ strictness: AnswerStrictness) {
        repository.setStrictness(strictness)
    }
}
