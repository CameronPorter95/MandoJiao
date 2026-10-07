import Foundation
import PracticeDomain

/// Everything the matching lesson screen renders.
struct MatchingState: Equatable {
    let title: String
    /// Nil when the request held too few words for a board.
    var lesson: MatchingLesson?
    var showsPinyin = false
    var isConfirmingQuit = false

    /// Closing before anything is matched, or after the end, needs no confirmation.
    var canCloseWithoutConfirming: Bool {
        guard let lesson else { return true }
        return lesson.isFinished || lesson.progress == 0
    }
}
