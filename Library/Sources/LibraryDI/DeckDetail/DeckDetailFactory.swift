import CoreDI
import CoreUI
import LibraryDomain
import LibraryUI

public enum DeckDetailFactory: NavigationInputRouteFactory {
    public static func makeRoute(
        dependencies: Dependencies,
        navigation: DeckDetailNavigation,
        input: DeckDetailInput
    ) -> DeckDetailRoute {
        DeckDetailRoute(viewModel: makeViewModel(dependencies: dependencies, input: input), navigation: navigation)
    }

    /// The deck without its view, renaming without waiting on the clock.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: DeckDetailNavigation,
        input: DeckDetailInput
    ) -> ScreenDriver {
        makeViewModel(dependencies: dependencies, input: input, renameDelay: .zero).driver(navigation: navigation)
    }

    private static func makeViewModel(
        dependencies: Dependencies,
        input: DeckDetailInput,
        renameDelay: Duration = DeckDetailViewModel.defaultRenameDelay
    ) -> DeckDetailViewModel {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return DeckDetailViewModel(
            deckID: input.deckID,
            minimumMatchingWords: input.minimumMatchingWords,
            vocabulary: input.vocabulary,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            renameDeck: RenameDeckUseCase(repository: repository),
            setMembership: SetDeckMembershipUseCase(repository: repository),
            moveDeck: MoveDeckUseCase(repository: repository),
            renameDelay: renameDelay
        )
    }
}
