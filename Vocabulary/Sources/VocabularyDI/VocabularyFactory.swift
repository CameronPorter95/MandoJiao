import SwiftData
import SwiftUI
import VocabularyData
import VocabularyDomain
import VocabularyUI

/// The only place that assembles the vocabulary's screens from its concrete parts.
@MainActor
public struct VocabularyFactory {
    let repository: any VocabularyRepository
    /// The matching exercise's floor and round count, handed in by the app.
    let minimumMatchingWords: Int
    let quickPracticeRounds: Int

    public init(container: ModelContainer, minimumMatchingWords: Int, quickPracticeRounds: Int) {
        repository = VocabularyStore.makeRepository(container: container)
        self.minimumMatchingWords = minimumMatchingWords
        self.quickPracticeRounds = quickPracticeRounds
    }

    /// Opens the store, migrating an older schema, and fills an empty one with starter words.
    public static func openStore(inMemory: Bool = false) throws -> ModelContainer {
        let container = try VocabularyStore.makeContainer(inMemory: inMemory)
        VocabularyStore.seedIfNeeded(container)
        return container
    }

    public var recordLessonResults: RecordLessonResultsUseCase { RecordLessonResultsUseCase(repository: repository) }

    public func makeHomeRoute(
        didRequestMatching: @escaping (LessonRequest) -> Void,
        didRequestSpeaking: @escaping (LessonRequest) -> Void,
        settings: @escaping () -> AnyView
    ) -> some View {
        let viewModel = HomeViewModel(
            minimumMatchingWords: minimumMatchingWords,
            quickPracticeRounds: quickPracticeRounds,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            createDeck: CreateDeckUseCase(repository: repository),
            deleteDeck: DeleteDeckUseCase(repository: repository),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        let navigation = HomeNavigation(didRequestMatching: didRequestMatching, didRequestSpeaking: didRequestSpeaking)
        let deckNavigation = DeckDetailNavigation(didRequestMatching: didRequestMatching)
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
