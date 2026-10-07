import CoreDomain
import CoreUI
import Foundation
import LibraryDomain

/// What the user is told when a change made from Home fails, and what gets logged.
nonisolated enum ProgressError: LoggedError, Equatable, Sendable {
    case clearMistakesFailed(VocabularyDomainError)

    var errorDescription: String? {
        switch self {
        case .clearMistakesFailed: "The mistakes list could not be cleared."
        }
    }

    var loggedModel: DomainErrorModel {
        switch self {
        case .clearMistakesFailed(let error): error.model
        }
    }

    var logContext: String {
        switch self {
        case .clearMistakesFailed: "clearMistakes"
        }
    }

    /// Runs a write. On failure: mints the display error, logs it, then hands it on to be
    /// shown. Cancellation is not a failure and produces nothing.
    @MainActor
    static func performing(
        _ work: () async throws -> Void,
        failure makeError: (VocabularyDomainError) -> ProgressError,
        show: (ProgressError) -> Void
    ) async -> WriteOutcome {
        do {
            try await work()
            return .succeeded
        } catch is CancellationError {
            return .cancelled
        } catch {
            let displayError = makeError(VocabularyDomainError(error))
            displayError.log()
            show(displayError)
            return .failed
        }
    }
}
