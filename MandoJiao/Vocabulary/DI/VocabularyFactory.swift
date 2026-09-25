import SwiftData
import SwiftUI

/// The only place that names the vocabulary's concrete implementations.
@MainActor
struct VocabularyFactory {
    let repository: any VocabularyRepository
    /// The matching exercise's floor and round count, handed in by the app.
    let minimumMatchingWords: Int
    let quickPracticeRounds: Int

    init(container: ModelContainer, minimumMatchingWords: Int, quickPracticeRounds: Int) {
        repository = VocabularyRepositoryImpl(localSource: VocabularyLocalSourceImpl(modelContainer: container))
        self.minimumMatchingWords = minimumMatchingWords
        self.quickPracticeRounds = quickPracticeRounds
    }

    /// Opens the store, migrating an older schema if there is one.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV2.self),
            migrationPlan: VocabularyMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    var recordLessonResults: RecordLessonResultsUseCase { RecordLessonResultsUseCase(repository: repository) }

    func makeHomeRoute(
        navigation: HomeNavigation,
        settings: @escaping () -> AnyView
    ) -> HomeRoute {
        let viewModel = HomeViewModel(
            minimumMatchingWords: minimumMatchingWords,
            quickPracticeRounds: quickPracticeRounds,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        let deckNavigation = DeckDetailNavigation(didRequestMatching: navigation.didRequestMatching)
        return HomeRoute(viewModel: viewModel, navigation: navigation) { destination in
            switch destination {
            case .library: AnyView(makeLibraryRoute())
            case .deck(let id): AnyView(makeDeckDetailRoute(deckID: id, navigation: deckNavigation))
            case .settings: settings()
            }
        }
    }

    func makeLibraryRoute() -> WordLibraryRoute {
        let viewModel = WordLibraryViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository)
        )
        return WordLibraryRoute(viewModel: viewModel, makeEditor: makeWordEditorRoute)
    }

    func makeWordEditorRoute(word: Word?) -> WordEditorRoute {
        WordEditorRoute(
            viewModel: WordEditorViewModel(
                word: word,
                saveWord: SaveWordUseCase(repository: repository),
                deleteWords: DeleteWordsUseCase(repository: repository)
            )
        )
    }

    func makeDeckDetailRoute(deckID: UUID, navigation: DeckDetailNavigation) -> DeckDetailRoute {
        let viewModel = DeckDetailViewModel(
            deckID: deckID,
            minimumMatchingWords: minimumMatchingWords,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            renameDeck: RenameDeckUseCase(repository: repository),
            setMembership: SetDeckMembershipUseCase(repository: repository)
        )
        return DeckDetailRoute(viewModel: viewModel, navigation: navigation)
    }
}
