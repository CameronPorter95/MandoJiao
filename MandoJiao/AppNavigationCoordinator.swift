import Foundation
import Observation
import VocabularyDomain

/// App-level presentation state: which lesson, if any, is over the home stack.
@MainActor
@Observable
final class AppNavigationCoordinator {
    enum PresentedLesson: Identifiable {
        case matching(LessonRequest)
        case speaking(LessonRequest)

        var id: UUID {
            switch self {
            case .matching(let request), .speaking(let request): request.id
            }
        }
    }

    var presentedLesson: PresentedLesson?

    func present(_ lesson: PresentedLesson) {
        presentedLesson = lesson
    }

    func dismissLesson() {
        presentedLesson = nil
    }
}
