import CoreDI
import VocabularyDomain
import VocabularyUI

/// Input is the list's share of the library's layout, which the library owns.
public enum WordLibraryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input layout: WordListLayout) -> WordLibraryRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = WordLibraryViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository)
        )
        return WordLibraryRoute(
            viewModel: viewModel,
            layout: layout,
            makeEditor: { WordEditorFactory.makeRoute(dependencies: dependencies, input: $0) },
            makeDictionary: { DictionaryFactory.makeRoute(dependencies: dependencies, input: $0) }
        )
    }
}
