import Foundation

public nonisolated struct SetSkipsLearntWordsUseCase: Sendable {
    public let repository: any LessonSettingsRepository

    public init(repository: any LessonSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ skips: Bool) {
        repository.setSkipsLearntWords(skips)
    }
}
