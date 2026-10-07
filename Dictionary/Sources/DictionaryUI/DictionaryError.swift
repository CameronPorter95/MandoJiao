import CoreDomain
import CoreUI
import DictionaryDomain
import Foundation

/// What the user is told when the dictionary fails, and what gets logged.
nonisolated enum DictionaryError: LoggedError, Equatable, Sendable {
    case lookUpFailed(DictionaryDomainError)
    case searchFailed(DictionaryDomainError)

    var errorDescription: String? {
        switch self {
        case .lookUpFailed: "The dictionary could not be read."
        case .searchFailed: "The dictionary could not be searched."
        }
    }

    var loggedModel: DomainErrorModel {
        switch self {
        case .lookUpFailed(let error), .searchFailed(let error): error.model
        }
    }

    var logContext: String {
        switch self {
        case .lookUpFailed: "lookUpDictionary"
        case .searchFailed: "searchDictionary"
        }
    }
}
