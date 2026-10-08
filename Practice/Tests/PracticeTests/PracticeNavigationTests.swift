import Foundation
import Testing
import PracticeDI
import PracticeUI

@Suite("Practice navigation in the app")
@MainActor
struct PracticeNavigationTests {
    @Test("closing any lesson reaches the presenter's dismissal")
    func closingDismisses() {
        var dismissals = 0
        let navigation = PracticeNavigation.app(dismiss: { dismissals += 1 })

        navigation.matching.didClose()
        navigation.speaking.didClose()
        navigation.flashcards.didClose()
        navigation.mixedLesson.didClose()

        #expect(dismissals == 4)
    }
}
