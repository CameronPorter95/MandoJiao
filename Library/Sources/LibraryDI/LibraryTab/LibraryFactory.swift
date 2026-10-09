import CoreDI
import CoreUI
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
        let folder = { (folderID: UUID, context: LibraryPageContext) in
            AnyView(FolderDetailFactory.makeRoute(
                dependencies: dependencies,
                navigation: folderNavigation(navigation, context: context),
                input: folderInput(folderID, context: context, input: input)
            ))
        }
        return LibraryRoute(
            viewModel: makeViewModel(dependencies: dependencies, input: input),
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
                        input: deckInput(id, context: context, input: input)
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

    /// The tab without its view: its folders, decks, search results, word editor and HSK levels
    /// drive too. Dictionary pages opened from them do not.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: LibraryNavigation,
        input: LibraryInput
    ) -> ScreenDriver {
        let folder = { (folderID: UUID, context: LibraryPageContext) in
            FolderDetailFactory.makeDriver(
                dependencies: dependencies,
                navigation: folderNavigation(navigation, context: context),
                input: folderInput(folderID, context: context, input: input)
            )
        }
        return makeViewModel(dependencies: dependencies, input: input).driver(
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
                    DeckDetailFactory.makeDriver(
                        dependencies: dependencies,
                        navigation: navigation.deckDetail,
                        input: deckInput(id, context: context, input: input)
                    )
                }
            },
            results: { searchText, context in
                WordLibraryFactory.makeDriver(
                    dependencies: dependencies,
                    input: WordLibraryInput(
                        folderID: nil,
                        layout: context.wordList,
                        searchText: searchText,
                        vocabulary: context.vocabulary,
                        dictionary: input.dictionary
                    )
                )
            },
            editor: { target, dismissed in
                WordEditorFactory.makeDriver(
                    dependencies: dependencies,
                    input: WordEditorInput(target: target, dictionary: input.dictionary),
                    dismiss: dismissed
                )
            },
            hskLevels: { dismissed in
                HSKLevelsFactory.makeDriver(dependencies: dependencies, input: input.dictionary, dismiss: dismissed)
            }
        )
    }

    private static func makeViewModel(dependencies: Dependencies, input: LibraryInput) -> LibraryViewModel {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let layout = VocabularyRepositoryFactory.makeLibraryLayoutRepository()
        return LibraryViewModel(
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
    }

    private static func folderNavigation(_ navigation: LibraryNavigation, context: LibraryPageContext) -> FolderDetailNavigation {
        .library(
            presentMatching: navigation.libraryTab.didRequestMatching,
            presentFlashcards: navigation.libraryTab.didRequestFlashcards,
            presentSpeaking: navigation.libraryTab.didRequestSpeaking,
            openDeck: context.openDeck,
            openFolder: context.openFolder
        )
    }

    private static func folderInput(_ folderID: UUID, context: LibraryPageContext, input: LibraryInput) -> FolderDetailInput {
        FolderDetailInput(
            folderID: folderID,
            minimumMatchingWords: input.minimumMatchingWords,
            layout: context.layout(folderID),
            wordList: context.wordList,
            vocabulary: context.vocabulary,
            dictionary: input.dictionary
        )
    }

    private static func deckInput(_ deckID: UUID, context: LibraryPageContext, input: LibraryInput) -> DeckDetailInput {
        DeckDetailInput(deckID: deckID, minimumMatchingWords: input.minimumMatchingWords, vocabulary: context.vocabulary)
    }
}
