import Foundation
import LibraryDomain
import Observation
import ProgressDomain

/// App-level navigation state: the open tab, and which lesson, if any, is over it.
@MainActor
@Observable
final class AppNavigationCoordinator {
    /// State rather than the tab bar's own, so something other than a tap can change it.
    enum AppTab: Hashable {
        case home
        case vocabulary
        case dictionary
    }

    var selectedTab = AppTab.home

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
