import CoreDomain
import Foundation

public nonisolated enum DictionaryDomainError: Error, Equatable, Sendable {
    /// A bundled file could not be read.
    case unexpected(model: DomainErrorModel)

    public var model: DomainErrorModel {
        switch self {
        case .unexpected(let model): model
        }
    }
}
