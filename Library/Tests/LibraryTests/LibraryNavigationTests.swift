import Foundation
import Testing
import LibraryDI
import LibraryDomain
import LibraryUI

@Suite("Vocabulary navigation in the app")
@MainActor
struct VocabularyNavigationTests {
    private let request = LessonRequest(title: "t", pool: [])

    @Test("a deck's and the library's lessons all reach the presenter, each as its own kind")
    func lessonsReachThePresenter() {
        var presented: [String] = []
        let navigation = LibraryNavigation.app(
            presentMatching: { presented.append("matching \($0.id == request.id)") },
            presentSpeaking: { presented.append("speaking \($0.id == request.id)") },
            presentFlashcards: { presented.append("flashcards \($0.id == request.id)") }
        )

        navigation.deckDetail.didRequestMatching(request)
        navigation.deckDetail.didRequestFlashcards(request)
        navigation.deckDetail.didRequestSpeaking(request)
        navigation.libraryTab.didRequestMatching(request)
        navigation.libraryTab.didRequestFlashcards(request)
        navigation.libraryTab.didRequestSpeaking(request)

        #expect(presented == [
            "matching true", "flashcards true", "speaking true",
            "matching true", "flashcards true", "speaking true",
        ])
    }
}
