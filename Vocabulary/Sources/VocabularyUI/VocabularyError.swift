import CoreDomain
import CoreUI
import Foundation
import VocabularyDomain

/// What the user is told when a library change fails, and what gets logged.
enum VocabularyError: LoggedError, Equatable, Sendable {
    case saveWordFailed(VocabularyDomainError)
    case deleteWordsFailed(VocabularyDomainError)
    case createDeckFailed(VocabularyDomainError)
    case renameDeckFailed(VocabularyDomainError)
    case updateDeckFailed(VocabularyDomainError)
    case deleteDeckFailed(VocabularyDomainError)
    case clearMistakesFailed(VocabularyDomainError)

    var errorDescription: String? {
        switch self {
        case .saveWordFailed: "The word could not be saved."
        case .deleteWordsFailed: "The words could not be deleted."
        case .createDeckFailed: "The deck could not be created."
        case .renameDeckFailed: "The deck could not be renamed."
        case .updateDeckFailed: "The deck's words could not be changed."
        case .deleteDeckFailed: "The deck could not be deleted."
        case .clearMistakesFailed: "The mistakes list could not be cleared."
        }
    }

    var domainError: VocabularyDomainError {
        switch self {
        case .saveWordFailed(let error), .deleteWordsFailed(let error), .createDeckFailed(let error),
             .renameDeckFailed(let error), .updateDeckFailed(let error), .deleteDeckFailed(let error),
             .clearMistakesFailed(let error):
            error
        }
    }

    var loggedModel: DomainErrorModel { domainError.model }

    var logContext: String {
        switch self {
        case .saveWordFailed: "saveWord"
        case .deleteWordsFailed: "deleteWords"
        case .createDeckFailed: "createDeck"
        case .renameDeckFailed: "renameDeck"
        case .updateDeckFailed: "updateDeck"
        case .deleteDeckFailed: "deleteDeck"
        case .clearMistakesFailed: "clearMistakes"
        }
    }

    /// Runs a write. On failure: mints the display error, logs it, then hands it on to be
    /// shown. Cancellation is not a failure and produces nothing.
    @MainActor
    static func performing(
        _ work: () async throws -> Void,
        failure makeError: (VocabularyDomainError) -> VocabularyError,
        show: (VocabularyError) -> Void
    ) async -> WriteOutcome {
        do {
            try await work()
            return .succeeded
        } catch is CancellationError {
            return .cancelled
        } catch {
            let domainError = error as? VocabularyDomainError ?? .unexpected(model: DomainErrorModel(error))
            let displayError = makeError(domainError)
            displayError.log()
            show(displayError)
            return .failed
        }
    }
}
