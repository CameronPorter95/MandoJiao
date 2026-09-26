import Foundation
import VocabularyDomain

struct HomeState: Equatable {
    var vocabulary: Vocabulary = .empty
    /// The matching exercise's floor, handed in so this package need not know Matching.
    let minimumMatchingWords: Int
    /// Shown on the quick practice card. Re-read on every appearance, since the settings
    /// screen can change it while home is underneath.
    var quickPracticeRounds: Int
    var isNamingDeck = false
    var newDeckName = ""
    var isConfirmingClear = false

    var usableWordCount: Int { vocabulary.usableWords.count }
    var canStartQuickPractice: Bool { usableWordCount >= minimumMatchingWords }
    var mistakeWords: [Word] { vocabulary.mistakeWords }

    var mistakesSubtitle: String {
        let count = mistakeWords.count
        let noun = count == 1 ? "word" : "words"
        return "\(count) \(noun) to earn back. Say each one out loud, one at a time."
    }

    func canStartLesson(with deck: DeckSummary) -> Bool {
        vocabulary.usableWordCount(in: deck) >= minimumMatchingWords
    }

    func subtitle(for deck: DeckSummary) -> String {
        let count = vocabulary.usableWordCount(in: deck)
        if count < minimumMatchingWords {
            return "\(count) words, needs \(minimumMatchingWords)"
        }
        return "\(count) words"
    }
}

enum HomeAction: Equatable {
    case appeared
    case disappeared
    case quickPracticeTapped
    case practiseMistakesTapped
    case practiseDeckTapped(UUID)
    case deleteDeckTapped(UUID)
    case newDeckTapped
    case newDeckNameChanged(String)
    case createDeckConfirmed
    case createDeckCancelled
    case clearMistakesTapped
    case clearMistakesConfirmed
    case clearMistakesCancelled
}

enum HomeEffect: Equatable, Sendable {
    case requestMatching(LessonRequest)
    case requestSpeaking(LessonRequest)
    case showError(VocabularyError)
}
