import Foundation
import VocabularyDomain

struct HomeState: Equatable {
    var vocabulary: Vocabulary = .empty
    /// The matching exercise's floor, handed in so this package need not know Matching.
    let minimumMatchingWords: Int
    /// Shown on the quick practice card. Re-read on every appearance, since the settings
    /// screen can change it while home is underneath.
    var quickPracticeRounds: Int
    var isConfirmingClear = false

    var usableWordCount: Int { vocabulary.usableWords.count }
    var canStartQuickPractice: Bool { usableWordCount >= minimumMatchingWords }
    var mistakeWords: [Word] { vocabulary.mistakeWords }

    var mistakesSubtitle: String {
        let count = mistakeWords.count
        let noun = count == 1 ? "word" : "words"
        return "\(count) \(noun) to earn back. Say each one out loud, one at a time."
    }
}

enum HomeAction: Equatable {
    case appeared
    case disappeared
    case quickPracticeTapped
    case practiseMistakesTapped
    case clearMistakesTapped
    case clearMistakesConfirmed
    case clearMistakesCancelled
}

enum HomeEffect: Equatable, Sendable {
    case requestMatching(LessonRequest)
    case requestSpeaking(LessonRequest)
    case showError(VocabularyError)
}
