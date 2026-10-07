import PracticeDI
import PracticeUI
import VocabularyDI
import VocabularyUI

/// Every package's navigation, built once at the composition root.
///
/// One property per package, so a factory call takes a single navigation value however
/// many screens a package gains. This is the only place that sees every package, so it
/// is where one package's screen leading to another's is decided.
@MainActor
struct AppNavigation {
    var vocabulary: VocabularyNavigation
    var matching: MatchingNavigation
    var speaking: SpeakingNavigation
    var flashcards: FlashcardsNavigation
    var mixedLesson: MixedLessonNavigation
}

extension AppNavigation {
    /// Home at the root, with lessons presented over it.
    static func main(coordinator: AppNavigationCoordinator) -> Self {
        AppNavigation(
            vocabulary: .app(
                presentMatching: { coordinator.present(.matching($0)) },
                presentSpeaking: { coordinator.present(.speaking($0)) },
                presentFlashcards: { coordinator.present(.flashcards($0)) },
                presentTodayPlan: { coordinator.present(.todayPlan($0)) }
            ),
            matching: .app(dismiss: { coordinator.dismissLesson() }),
            speaking: .app(dismiss: { coordinator.dismissLesson() }),
            flashcards: .app(dismiss: { coordinator.dismissLesson() }),
            mixedLesson: .app(dismiss: { coordinator.dismissLesson() })
        )
    }
}
