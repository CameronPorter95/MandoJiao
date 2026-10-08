import DictionaryDomain
import Foundation
import LibraryDomain
import PracticeDomain

/// Everything the mixed lesson's screen renders.
struct MixedLessonState: Equatable {
    var lesson: MixedLesson
    var isConfirmingQuit = false
    /// A sentence using each taught word, by its id, as they arrive. A word with none
    /// has no example on its card.
    var examples: [UUID: ExampleSentence] = [:]

    /// Closing before anything is answered, or after the end, needs no confirmation.
    var canCloseWithoutConfirming: Bool {
        lesson.isFinished || lesson.stepIndex == 0
    }
}

enum MixedLessonAction: Equatable {
    case stepCompleted([Answer], carriesOn: Bool = false)
    case appeared
    case disappeared
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled
}

enum MixedLessonEffect: Equatable, Sendable {
    case showError(MixedLessonError)
    case close
}
