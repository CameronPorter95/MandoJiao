import Foundation

public nonisolated struct GetLessonSettingsUseCase: Sendable {
    public let repository: any LessonSettingsRepository

    public init(repository: any LessonSettingsRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> LessonSettings {
        repository.settings()
    }
}
