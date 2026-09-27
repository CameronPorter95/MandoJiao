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
            presentSpeaking: { presented.append("speaking \($0.id == request.id)") }
        )

        navigation.home.didRequestMatching(request)
        navigation.home.didRequestSpeaking(request)
        navigation.deckDetail.didRequestMatching(request)
        navigation.library.didRequestMatching(request)

        #expect(presented == ["matching true", "speaking true", "matching true", "matching true"])
    }
}
