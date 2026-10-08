import CoreDI
import LibraryDomain
import LibraryUI
import SwiftUI

/// The composition root for the library tab and the stack beside its tree, which is why it
/// takes the package's whole navigation bundle.
public enum LibraryFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: LibraryNavigation,
        input: LibraryInput
    ) -> LibraryRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let layout = VocabularyRepositoryFactory.makeLibraryLayoutRepository()
        let viewModel = LibraryViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            createFolder: CreateFolderUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            moveFolder: MoveFolderUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository),
            getLayout: GetLibraryLayoutUseCase(repository: layout),
            saveLayout: SaveLibraryLayoutUseCase(repository: layout)
        )
        let folder = { (folderID: UUID, context: LibraryPageContext) in
            AnyView(FolderDetailFactory.makeRoute(
                dependencies: dependencies,
                navigation: .library(
                    presentMatching: navigation.libraryTab.didRequestMatching,
                    presentFlashcards: navigation.libraryTab.didRequestFlashcards,
                    presentSpeaking: navigation.libraryTab.didRequestSpeaking,
                    openDeck: context.openDeck,
                    openFolder: context.openFolder
                ),
                input: FolderDetailInput(
                    folderID: folderID,
                    minimumMatchingWords: input.minimumMatchingWords,
                    layout: context.layout(folderID),
                    wordList: context.wordList,
                    vocabulary: context.vocabulary,
                    dictionary: input.dictionary
                )
            ))
        }
        return LibraryRoute(
            viewModel: viewModel,
            navigation: navigation.libraryTab,
            root: { selection, context in
                switch selection {
                case .folder(let id): folder(id, context)
                }
            },
            page: { page, context in
                switch page {
                case .folder(let id):
                    folder(id, context)
                case .deck(let id):
                    AnyView(DeckDetailFactory.makeRoute(
                        dependencies: dependencies,
                        navigation: navigation.deckDetail,
                        input: DeckDetailInput(
                            deckID: id,
                            minimumMatchingWords: input.minimumMatchingWords,
                            vocabulary: context.vocabulary
                        )
                    ))
                }
            },
            results: { searchText, context in
                AnyView(WordLibraryFactory.makeRoute(
                    dependencies: dependencies,
                    input: WordLibraryInput(
                        folderID: nil,
                        layout: context.wordList,
                        searchText: searchText,
                        vocabulary: context.vocabulary,
                        dictionary: input.dictionary
                    )
                ))
            },
            makeEditor: { WordEditorFactory.makeRoute(dependencies: dependencies, input: WordEditorInput(target: $0, dictionary: input.dictionary)) },
            hskLevels: { AnyView(HSKLevelsFactory.makeRoute(dependencies: dependencies, input: input.dictionary)) }
        )
    }
}
