import CoreDI
import SwiftUI
import VocabularyDomain
import VocabularyUI

/// The package's composition root for the home screen and the stack pushed from it.
public enum HomeFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: HomeNavigation,
        input: HomeInput
    ) -> HomeRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = HomeViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            quickPracticeRounds: input.quickPracticeRounds,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        let deckNavigation = DeckDetailNavigation(didRequestMatching: navigation.didRequestMatching)

        return HomeRoute(viewModel: viewModel, navigation: navigation) { destination in
            switch destination {
            case .library:
                AnyView(WordLibraryFactory.makeRoute(dependencies: dependencies))
            case .deck(let id):
                AnyView(DeckDetailFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: deckNavigation,
                    input: DeckDetailInput(deckID: id, minimumMatchingWords: input.minimumMatchingWords)
                ))
            case .settings:
                input.settings()
            }
        }
    }
}
