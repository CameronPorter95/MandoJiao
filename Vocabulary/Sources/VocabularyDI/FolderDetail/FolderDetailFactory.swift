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
            vocabulary: input.vocabulary,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            createDeck: CreateDeckUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository)
        )
        return FolderDetailRoute(viewModel: viewModel, navigation: navigation, layout: input.layout) { searchText in
            WordLibraryFactory.makeRoute(
                dependencies: dependencies,
                input: WordLibraryInput(
                    folderID: input.folderID,
                    layout: input.wordList,
                    searchText: searchText,
                    vocabulary: input.vocabulary
                )
            )
        }
    }
}
