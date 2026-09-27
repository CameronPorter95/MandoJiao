import CoreDomain
import Foundation

public nonisolated enum VocabularyDomainError: Error, Equatable, Sendable {
    /// The store failed to read or write.
    case persistence(model: DomainErrorModel)
    case unexpected(model: DomainErrorModel)

    public var model: DomainErrorModel {
        switch self {
        case .persistence(let model), .unexpected(let model): model
        }
    }
}
