import Foundation

public nonisolated struct SaveLibraryLayoutUseCase: Sendable {
    public let repository: any LibraryLayoutRepository

    public init(repository: any LibraryLayoutRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ layout: LibraryLayout) {
        repository.save(layout)
    }
}
