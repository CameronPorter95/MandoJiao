import CoreDI
import VocabularyDomain
import VocabularyUI

public enum FolderDetailFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: FolderDetailNavigation,
        input: FolderDetailInput
    ) -> FolderDetailRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = FolderDetailViewModel(
            folderID: input.folderID,
            minimumMatchingWords: input.minimumMatchingWords,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            moveDeck: MoveDeckUseCase(repository: repository)
        )
        return FolderDetailRoute(viewModel: viewModel, navigation: navigation, openDeck: input.openDeck)
    }
}
