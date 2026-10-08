import LibraryDI
import LibraryUI
import PracticeDI
import PracticeUI
import ProgressDI
import ProgressUI

/// Every package's navigation, built once at the composition root.
///
/// One property per package, so a factory call takes a single navigation value however
/// many screens a package gains. This is the only place that sees every package, so it
/// is where one package's screen leading to another's is decided.
@MainActor
struct AppNavigation {
    var progress: ProgressNavigation
    var library: LibraryNavigation
    var practice: PracticeNavigation
}

extension AppNavigation {
    /// Home at the root, with lessons presented over it.
    static func main(coordinator: AppNavigationCoordinator) -> Self {
        AppNavigation(
            progress: .app(
                presentMatching: { coordinator.present(.matching($0)) },
                presentSpeaking: { coordinator.present(.speaking($0)) },
                presentFlashcards: { coordinator.present(.flashcards($0)) },
                presentTodayPlan: { coordinator.present(.todayPlan($0)) }
            ),
            library: .app(
                presentMatching: { coordinator.present(.matching($0)) },
                presentSpeaking: { coordinator.present(.speaking($0)) },
                presentFlashcards: { coordinator.present(.flashcards($0)) }
            ),
            practice: .app(dismiss: { coordinator.dismissLesson() })
        )
    }
}
