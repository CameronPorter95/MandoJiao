import Foundation

public nonisolated struct ObserveSavedReadingsUseCase: Sendable {
    public let repository: any SavedReadingsRepository

    public init(repository: any SavedReadingsRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> AsyncStream<[SavedReading]> {
        repository.savedReadings()
    }
}
