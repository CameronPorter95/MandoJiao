import CoreDI
import SwiftUI
import VocabularyDomain
import VocabularyUI

/// The package's composition root for the home screen and the stack pushed from it,
/// which is why it takes the package's whole navigation bundle.
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
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        return HomeRoute(viewModel: viewModel, navigation: navigation.home) { destination in
            switch destination {
            case .library:
                AnyView(WordLibraryFactory.makeRoute(dependencies: dependencies))
            case .deck(let id):
                AnyView(DeckDetailFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.deckDetail,
                    input: DeckDetailInput(deckID: id, minimumMatchingWords: input.minimumMatchingWords)
                ))
            case .folder(let id):
                AnyView(FolderDetailFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.folderDetail,
                    input: FolderDetailInput(folderID: id, minimumMatchingWords: input.minimumMatchingWords)
                ))
            case .settings:
                input.settings()
            }
        }
    }
}
