import CoreDI
import SwiftUI
import VocabularyDomain
import VocabularyUI

/// The package's composition root for the home tab and the stack pushed from it.
public enum HomeFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: VocabularyNavigation,
        input: HomeInput
    ) -> HomeRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = HomeViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            quickPracticeRounds: input.quickPracticeRounds,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        return HomeRoute(viewModel: viewModel, navigation: navigation.home) { destination in
            switch destination {
            case .settings:
                input.settings()
            }
        }
    }
}
