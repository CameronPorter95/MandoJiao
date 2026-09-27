import CoreDomain
import Foundation

/// Thrown by a local source when the store itself fails, so a repository can classify it.
public nonisolated struct LocalStoreError: Error, Sendable {
    public let model: DomainErrorModel

    public init(_ error: any Error) {
        model = DomainErrorModel(error)
    }
}
