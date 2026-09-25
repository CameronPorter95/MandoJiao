import Foundation

/// Thrown by a local source when the store itself fails, so a repository can classify it.
nonisolated struct LocalStoreError: Error, Sendable {
    let model: DomainErrorModel

    init(_ error: any Error) {
        model = DomainErrorModel(error)
    }
}
