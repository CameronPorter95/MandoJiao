import CoreDI
import ProgressUI
import SwiftUI

/// The package's composition root for the home tab and the stack pushed from it, which is
/// why it takes the package's whole navigation bundle.
public enum HomeFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: ProgressNavigation,
        input: HomeInput
    ) -> HomeRoute {
        let viewModel = HomeViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            quickPracticeRounds: input.quickPracticeRounds,
            observeVocabulary: input.observeVocabulary,
            getLessonSettings: input.getLessonSettings,
            clearMistakes: input.clearMistakes
        )
        return HomeRoute(viewModel: viewModel, navigation: navigation.home) { destination in
            switch destination {
            case .settings:
                input.settings()
            }
        }
    }
}
