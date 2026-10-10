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
    /// Taught words whose example is still being looked for, by id. A word leaves once a
    /// sentence is found for it or every source has been tried.
    var examplesPending: Set<UUID> = []

    /// Closing before anything is answered, or after the end, needs no confirmation. A taught
    /// word answers nothing, so passing one is not reason enough to ask.
    var canCloseWithoutConfirming: Bool {
        lesson.isFinished || lesson.answers.isEmpty
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
