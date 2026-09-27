import CoreDI
import VocabularyDomain
import VocabularyUI

public enum DeckDetailFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: DeckDetailNavigation,
        input: DeckDetailInput
    ) -> DeckDetailRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = DeckDetailViewModel(
            deckID: input.deckID,
            minimumMatchingWords: input.minimumMatchingWords,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            renameDeck: RenameDeckUseCase(repository: repository),
            setMembership: SetDeckMembershipUseCase(repository: repository)
        )
        return DeckDetailRoute(viewModel: viewModel, navigation: navigation)
    }
}
