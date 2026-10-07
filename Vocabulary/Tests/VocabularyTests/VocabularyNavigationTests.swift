import Foundation
import Testing
import VocabularyDI
import VocabularyDomain
import VocabularyUI

@Suite("Vocabulary navigation in the app")
@MainActor
struct VocabularyNavigationTests {
    private let request = LessonRequest(title: "t", pool: [])

    @Test("home's, a deck's and the library's lessons all reach the presenter, each as its own kind")
    func lessonsReachThePresenter() {
        var presented: [String] = []
        let navigation = VocabularyNavigation.app(
            presentMatching: { presented.append("matching \($0.id == request.id)") },
            presentSpeaking: { presented.append("speaking \($0.id == request.id)") },
            presentFlashcards: { presented.append("flashcards \($0.id == request.id)") },
            presentTodayPlan: { _ in presented.append("today") }
        )

        navigation.home.didRequestMatching(request)
        navigation.home.didRequestSpeaking(request)
        navigation.deckDetail.didRequestMatching(request)
        navigation.deckDetail.didRequestFlashcards(request)
        navigation.deckDetail.didRequestSpeaking(request)
        navigation.library.didRequestMatching(request)
        navigation.library.didRequestFlashcards(request)
        navigation.library.didRequestSpeaking(request)

        #expect(presented == [
            "matching true", "speaking true",
            "matching true", "flashcards true", "speaking true",
            "matching true", "flashcards true", "speaking true",
        ])
    }
}
