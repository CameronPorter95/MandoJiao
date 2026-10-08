import CoreDI
import CoreUI
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
        HomeRoute(viewModel: makeViewModel(input: input), navigation: navigation.home) { destination in
            switch destination {
            case .settings:
                input.settings()
            }
        }
    }

    /// Home without its view. The settings screen pushed from it is not driven.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: ProgressNavigation,
        input: HomeInput
    ) -> ScreenDriver {
        makeViewModel(input: input).driver(navigation: navigation.home)
    }

    private static func makeViewModel(input: HomeInput) -> HomeViewModel {
        HomeViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            quickPracticeRounds: input.quickPracticeRounds,
            observeVocabulary: input.observeVocabulary,
            getLessonSettings: input.getLessonSettings,
            clearMistakes: input.clearMistakes
        )
    }
}
