import CoreDI
import VocabularyDomain
import VocabularyUI

public enum WordLibraryFactory: RouteFactory {
    public static func makeRoute(dependencies: Dependencies) -> WordLibraryRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let viewModel = WordLibraryViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository)
        )
        return WordLibraryRoute(viewModel: viewModel) { word in
            WordEditorFactory.makeRoute(dependencies: dependencies, input: word)
        }
    }
}
