import CoreDI
import VocabularyDomain
import VocabularyUI

public enum WordLibraryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: WordLibraryInput) -> WordLibraryRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = WordLibraryViewModel(
            folderID: input.folderID,
            vocabulary: input.vocabulary,
            sort: input.layout.sort,
            searchText: input.searchText,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            setLearnt: SetWordLearntUseCase(repository: repository)
        )
        return WordLibraryRoute(
            viewModel: viewModel,
            layout: input.layout,
            searchText: input.searchText,
            makeEditor: { WordEditorFactory.makeRoute(dependencies: dependencies, input: $0) },
            makeDictionary: { DictionaryFactory.makeRoute(dependencies: dependencies, input: DictionaryInput(headword: $0, addsToVocabulary: true)) }
        )
    }
}
