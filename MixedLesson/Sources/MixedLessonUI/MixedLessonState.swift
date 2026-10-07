import Foundation
import MixedLessonDomain
import VocabularyDomain

/// Everything the mixed lesson's screen renders.
struct MixedLessonState: Equatable {
    var lesson: MixedLesson
    var isConfirmingQuit = false

    /// Closing before anything is answered, or after the end, needs no confirmation.
    var canCloseWithoutConfirming: Bool {
        lesson.isFinished || lesson.stepIndex == 0
    }
}

enum MixedLessonAction: Equatable {
    case stepCompleted([Answer])
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled
}

enum MixedLessonEffect: Equatable, Sendable {
    case showError(MixedLessonError)
    case close
}
