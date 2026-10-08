import CoreDI
import CoreUI
import LibraryDomain
import LibraryUI

public enum FolderDetailFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: FolderDetailNavigation,
        input: FolderDetailInput
    ) -> FolderDetailRoute {
        let viewModel = makeViewModel(dependencies: dependencies, input: input)
        return FolderDetailRoute(viewModel: viewModel, navigation: navigation, layout: input.layout) { searchText in
            WordLibraryFactory.makeRoute(
                dependencies: dependencies,
                input: WordLibraryInput(
                    folderID: input.folderID,
                    layout: input.wordList,
                    searchText: searchText,
                    vocabulary: input.vocabulary,
                    dictionary: input.dictionary
                )
            )
        }
    }

    /// The folder without its view. Its search results are not driven.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: FolderDetailNavigation,
        input: FolderDetailInput
    ) -> ScreenDriver {
        makeViewModel(dependencies: dependencies, input: input).driver(navigation: navigation)
    }

    private static func makeViewModel(dependencies: Dependencies, input: FolderDetailInput) -> FolderDetailViewModel {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return FolderDetailViewModel(
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
    }
}
