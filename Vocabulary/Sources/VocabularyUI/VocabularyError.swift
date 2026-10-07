import CoreDomain
import CoreUI
import Foundation
import VocabularyDomain

/// What the user is told when a library change fails, and what gets logged.
nonisolated enum VocabularyError: LoggedError, Equatable, Sendable {
    case saveWordFailed(VocabularyDomainError)
    case setLearntFailed(VocabularyDomainError)
    case deleteWordsFailed(VocabularyDomainError)
    case createDeckFailed(VocabularyDomainError)
    case renameDeckFailed(VocabularyDomainError)
    case updateDeckFailed(VocabularyDomainError)
    case deleteDeckFailed(VocabularyDomainError)
    case moveDeckFailed(VocabularyDomainError)
    case createFolderFailed(VocabularyDomainError)
    case renameFolderFailed(VocabularyDomainError)
    case moveFolderFailed(VocabularyDomainError)
    case deleteFolderFailed(VocabularyDomainError)
    case loadHSKFailed(VocabularyDomainError)
    case installHSKFailed(VocabularyDomainError)
    case clearMistakesFailed(VocabularyDomainError)
    case suggestWordFailed(VocabularyDomainError)
    case lookUpDictionaryFailed(VocabularyDomainError)
    case searchDictionaryFailed(VocabularyDomainError)

    var errorDescription: String? {
        switch self {
        case .saveWordFailed: "The word could not be saved."
        case .setLearntFailed: "The word could not be marked."
        case .deleteWordsFailed: "The words could not be deleted."
        case .createDeckFailed: "The deck could not be created."
        case .renameDeckFailed: "The deck could not be renamed."
        case .updateDeckFailed: "The deck's words could not be changed."
        case .deleteDeckFailed: "The deck could not be deleted."
        case .moveDeckFailed: "The deck could not be moved."
        case .createFolderFailed: "The folder could not be created."
        case .renameFolderFailed: "The folder could not be renamed."
        case .moveFolderFailed: "The folder could not be moved."
        case .deleteFolderFailed: "The folder could not be deleted."
        case .loadHSKFailed: "The HSK word list could not be read."
        case .installHSKFailed: "The HSK decks could not be added."
        case .clearMistakesFailed: "The mistakes list could not be cleared."
        case .suggestWordFailed: "No pinyin could be suggested."
        case .lookUpDictionaryFailed: "The dictionary could not be read."
        case .searchDictionaryFailed: "The dictionary could not be searched."
        }
    }

    var domainError: VocabularyDomainError {
        switch self {
        case .saveWordFailed(let error), .setLearntFailed(let error), .deleteWordsFailed(let error), .createDeckFailed(let error),
             .renameDeckFailed(let error), .updateDeckFailed(let error), .deleteDeckFailed(let error),
             .moveDeckFailed(let error), .createFolderFailed(let error), .renameFolderFailed(let error),
             .moveFolderFailed(let error), .deleteFolderFailed(let error), .loadHSKFailed(let error),
             .installHSKFailed(let error), .clearMistakesFailed(let error),
             .suggestWordFailed(let error), .lookUpDictionaryFailed(let error),
             .searchDictionaryFailed(let error):
            error
        }
    }

    var loggedModel: DomainErrorModel { domainError.model }

    var logContext: String {
        switch self {
        case .saveWordFailed: "saveWord"
        case .setLearntFailed: "setLearnt"
        case .deleteWordsFailed: "deleteWords"
        case .createDeckFailed: "createDeck"
        case .renameDeckFailed: "renameDeck"
        case .updateDeckFailed: "updateDeck"
        case .deleteDeckFailed: "deleteDeck"
        case .moveDeckFailed: "moveDeck"
        case .createFolderFailed: "createFolder"
        case .renameFolderFailed: "renameFolder"
        case .moveFolderFailed: "moveFolder"
        case .deleteFolderFailed: "deleteFolder"
        case .loadHSKFailed: "loadHSK"
        case .installHSKFailed: "installHSK"
        case .clearMistakesFailed: "clearMistakes"
        case .suggestWordFailed: "suggestWord"
        case .lookUpDictionaryFailed: "lookUpDictionary"
        case .searchDictionaryFailed: "searchDictionary"
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
