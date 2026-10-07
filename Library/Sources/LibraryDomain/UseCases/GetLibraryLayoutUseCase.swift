import Foundation

public nonisolated struct GetLibraryLayoutUseCase: Sendable {
    public let repository: any LibraryLayoutRepository

    public init(repository: any LibraryLayoutRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> LibraryLayout {
        repository.layout()
    }
}
