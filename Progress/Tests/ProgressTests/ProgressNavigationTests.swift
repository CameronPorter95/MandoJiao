import Foundation
import ProgressDI
import ProgressDomain
import ProgressUI
import Testing
import LibraryDomain

@Suite("Progress navigation in the app")
@MainActor
struct ProgressNavigationTests {
    private let request = LessonRequest(title: "t", pool: [])

    @Test("every lesson Home starts reaches the presenter as its own kind")
    func lessonsReachThePresenter() {
        var presented: [String] = []
        let plan = TodayPlan(theme: .review, title: "Review", synopsis: "", steps: [], source: nil, otherWords: [])
        let navigation = ProgressNavigation.app(
            presentMatching: { presented.append("matching \($0.id == request.id)") },
            presentSpeaking: { presented.append("speaking \($0.id == request.id)") },
            presentFlashcards: { presented.append("flashcards \($0.id == request.id)") },
            presentTodayPlan: { presented.append("today \($0.id == plan.id)") }
        )

        navigation.home.didRequestMatching(request)
        navigation.home.didRequestSpeaking(request)
        navigation.home.didRequestFlashcards(request)
        navigation.home.didRequestTodayPlan(plan)

        #expect(presented == ["matching true", "speaking true", "flashcards true", "today true"])
    }
}
