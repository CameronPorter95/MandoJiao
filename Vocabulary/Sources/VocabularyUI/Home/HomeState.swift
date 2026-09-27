import Foundation
import VocabularyDomain

struct HomeState: Equatable {
    var vocabulary: Vocabulary = .empty
    /// The matching exercise's floor, handed in so this package need not know Matching.
    let minimumMatchingWords: Int
    /// Shown on the quick practice card. Re-read on every appearance, since the settings
    /// screen can change it while home is underneath.
    var quickPracticeRounds: Int
    /// What the naming alert will create, while it is up.
    var naming: NewItemKind?
    var newItemName = ""
    var isConfirmingClear = false
    /// A folder with something inside, waiting on confirmation before it goes.
    var pendingFolderDeletion: UUID?

    var usableWordCount: Int { vocabulary.usableWords.count }
    var canStartQuickPractice: Bool { usableWordCount >= minimumMatchingWords }
    var mistakeWords: [Word] { vocabulary.mistakeWords }

    var mistakesSubtitle: String {
        let count = mistakeWords.count
        let noun = count == 1 ? "word" : "words"
        return "\(count) \(noun) to earn back. Say each one out loud, one at a time."
    }

    var folders: [FolderSummary] { vocabulary.folders(in: nil) }
    var decks: [DeckSummary] { vocabulary.decks(in: nil) }
    var isEmptyOfDecks: Bool { folders.isEmpty && decks.isEmpty }
    var deletionWarning: String? { pendingFolderDeletion.flatMap(vocabulary.deletionWarning(forFolder:)) }

    func canStartLesson(with deck: DeckSummary) -> Bool {
        vocabulary.canStartLesson(with: deck, minimumMatchingWords: minimumMatchingWords)
    }

    func subtitle(for deck: DeckSummary) -> String {
        vocabulary.subtitle(for: deck, minimumMatchingWords: minimumMatchingWords)
    }
}

enum HomeAction: Equatable {
    case appeared
    case disappeared
    case quickPracticeTapped
    case practiseMistakesTapped
    case practiseDeckTapped(UUID)
    case practiseFolderTapped(UUID)
    case deleteDeckTapped(UUID)
    case deleteFolderTapped(UUID)
    case deleteFolderConfirmed
    case deleteFolderCancelled
    case newItemTapped(NewItemKind)
    case newItemNameChanged(String)
    case createConfirmed
    case createCancelled
    case clearMistakesTapped
    case clearMistakesConfirmed
    case clearMistakesCancelled
}

enum HomeEffect: Equatable, Sendable {
    case requestMatching(LessonRequest)
    case requestSpeaking(LessonRequest)
    case showError(VocabularyError)
}
