import Foundation

nonisolated enum VocabularyDomainError: Error, Equatable, Sendable {
    /// The store failed to read or write.
    case persistence(model: DomainErrorModel)
    case unexpected(model: DomainErrorModel)

    var model: DomainErrorModel {
        switch self {
        case .persistence(let model), .unexpected(let model): model
        }
    }
}
