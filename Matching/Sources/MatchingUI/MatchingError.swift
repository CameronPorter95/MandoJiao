import CoreDomain
import CoreUI
import Foundation
import VocabularyDomain

nonisolated enum MatchingError: LoggedError, Equatable, Sendable {
    case recordResultsFailed(VocabularyDomainError)

    var errorDescription: String? {
        switch self {
        case .recordResultsFailed: "This lesson's results could not be saved to your mistakes list."
        }
    }

    var loggedModel: DomainErrorModel {
        switch self {
        case .recordResultsFailed(let error): error.model
        }
    }

    var logContext: String {
        switch self {
        case .recordResultsFailed: "recordMatchingResults"
        }
    }
}
