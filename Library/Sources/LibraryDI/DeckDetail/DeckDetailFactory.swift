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
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = DeckDetailViewModel(
            deckID: input.deckID,
            minimumMatchingWords: input.minimumMatchingWords,
            vocabulary: input.vocabulary,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getLessonSettings: LessonSettingsFactory.makeGetSettingsUseCase(dependencies: dependencies),
            renameDeck: RenameDeckUseCase(repository: repository),
            setMembership: SetDeckMembershipUseCase(repository: repository),
            moveDeck: MoveDeckUseCase(repository: repository)
        )
        return DeckDetailRoute(viewModel: viewModel, navigation: navigation)
    }

    /// The deck without its view, renaming without waiting on the clock.
    public static func makeDriver(
        dependencies: Dependencies,
        navigation: DeckDetailNavigation,
        input: DeckDetailInput
    ) -> ScreenDriver {
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
            renameDelay: .zero
        ).driver(navigation: navigation)
    }
}
