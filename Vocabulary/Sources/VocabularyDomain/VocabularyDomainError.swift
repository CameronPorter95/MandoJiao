import CoreDomain
import DictionaryDomain
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

public nonisolated extension VocabularyDomainError {
    /// Any failure as the library reports it, keeping the dictionary's own description.
    init(_ error: any Error) {
        switch error {
        case let error as VocabularyDomainError: self = error
        case let error as DictionaryDomainError: self = .unexpected(model: error.model)
        default: self = .unexpected(model: DomainErrorModel(error))
        }
    }
}
