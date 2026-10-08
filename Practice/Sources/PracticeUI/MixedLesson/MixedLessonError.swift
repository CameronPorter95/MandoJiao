import CoreDomain
import CoreUI
import Foundation
import LibraryDomain

nonisolated enum MixedLessonError: LoggedError, Equatable, Sendable {
    case recordResultsFailed(VocabularyDomainError)
    /// Logged, never shown.
    case findExamplesFailed(VocabularyDomainError)

    var errorDescription: String? {
        switch self {
        case .recordResultsFailed: "This lesson's results could not be saved."
        case .findExamplesFailed: "No example sentences could be read."
        }
    }

    var loggedModel: DomainErrorModel {
        switch self {
        case .recordResultsFailed(let error), .findExamplesFailed(let error): error.model
        }
    }

    var logContext: String {
        switch self {
        case .recordResultsFailed: "recordMixedLessonResults"
        case .findExamplesFailed: "findExamples"
        }
    }
}
