import CoreDI
import SwiftUI
import VocabularyDomain
import VocabularyUI

/// The composition root for the library tab and its columns, which is why it takes the
/// package's whole navigation bundle.
public enum LibraryFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: VocabularyNavigation,
        input: LibraryInput
    ) -> LibraryRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = LibraryViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createFolder: CreateFolderUseCase(repository: repository),
            renameFolder: RenameFolderUseCase(repository: repository),
            moveFolder: MoveFolderUseCase(repository: repository),
            deleteFolder: DeleteFolderUseCase(repository: repository)
        )
        return LibraryRoute(
            viewModel: viewModel,
            navigation: navigation.library,
            content: { selection, openDeck, column in
                switch selection {
                case .allWords:
                    return AnyView(WordLibraryFactory.makeRoute(dependencies: dependencies))
                case .folder(let folderID):
                    return AnyView(FolderDetailFactory.makeRoute(
                        dependencies: dependencies,
                        navigation: .library(
                            presentMatching: navigation.library.didRequestMatching,
                            openDeck: column.openDeck,
                            openFolder: column.openFolder
                        ),
                        input: FolderDetailInput(
                            folderID: folderID,
                            minimumMatchingWords: input.minimumMatchingWords,
                            openDeck: openDeck
                        )
                    ))
                }
            },
            detail: { deckID in
                AnyView(DeckDetailFactory.makeRoute(
                    dependencies: dependencies,
                    navigation: navigation.deckDetail,
                    input: DeckDetailInput(deckID: deckID, minimumMatchingWords: input.minimumMatchingWords)
                ))
            }
        )
    }
}
