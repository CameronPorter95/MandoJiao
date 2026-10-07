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
        case flashcards(LessonRequest)
        case todayPlan(TodayPlan)

        var id: UUID {
            switch self {
            case .matching(let request), .speaking(let request), .flashcards(let request): request.id
            case .todayPlan(let plan): plan.id
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
