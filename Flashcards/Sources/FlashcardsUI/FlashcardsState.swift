import FlashcardsDomain
import Foundation

/// Everything the flash card lesson screen renders.
struct FlashcardsState: Equatable {
    /// Nil when the request held no words a card can be made from.
    var lesson: FlashcardLesson?
    var isConfirmingQuit = false

    /// Closing before anything is answered, or after the end, needs no confirmation.
    var canCloseWithoutConfirming: Bool {
        guard let lesson else { return true }
        return lesson.isFinished || lesson.progress == 0
    }
}

enum FlashcardsAction: Equatable {
    case appeared
    case typedAnswerSubmitted(String)
    case optionPicked(UUID)
    case dontKnowTapped
    case continueTapped
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled
}

enum FlashcardsEffect: Equatable, Sendable {
    /// Every verdict gets one.
    case haptic(FlashcardsHaptic)
    case showError(FlashcardsError)
    case close
}

enum FlashcardsHaptic: Equatable, Sendable {
    case success
    case error
}
