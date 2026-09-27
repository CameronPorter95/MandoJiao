import CoreDI
import SwiftUI
import VocabularyDomain
import VocabularyUI

/// The composition root for the library tab and the stack beside its tree, which is why it
/// takes the package's whole navigation bundle.
public enum LibraryFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: VocabularyNavigation,
        input: LibraryInput
    ) -> LibraryRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let layout = VocabularyRepositoryFactory.makeLibraryLayoutRepository()
        let viewModel = LibraryViewModel(
            minimumMatchingWords: input.minimumMatchingWords,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
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
                    presentMatching: navigation.library.didRequestMatching,
                    openDeck: context.openDeck,
                    openFolder: context.openFolder
                ),
                input: FolderDetailInput(
                    folderID: folderID,
                    minimumMatchingWords: input.minimumMatchingWords,
                    layout: context.layout(folderID),
                    vocabulary: context.vocabulary
                )
            ))
        }
        return LibraryRoute(
            viewModel: viewModel,
            navigation: navigation.library,
            root: { selection, context in
                switch selection {
                case .allWords: AnyView(WordLibraryFactory.makeRoute(dependencies: dependencies))
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
            }
        )
    }
}
