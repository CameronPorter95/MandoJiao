import CoreDI
import VocabularyDomain
import VocabularyUI

public enum DictionaryTabFactory: RouteFactory {
    public static func makeRoute(dependencies: Dependencies) -> DictionaryTabRoute {
        let repository = VocabularyRepositoryFactory.makeDictionaryRepository()
        let lookUp = LookUpDictionaryUseCase(repository: repository)
        let observe = ObserveVocabularyUseCase(repository: VocabularyRepositoryFactory.makeRepository(dependencies: dependencies))
        return DictionaryTabRoute(
            viewModel: DictionarySearchViewModel(searchDictionary: SearchDictionaryUseCase(repository: repository), observeVocabulary: observe),
            makePage: { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp, observeVocabulary: observe) },
            makeEditor: { WordEditorFactory.makeRoute(dependencies: dependencies, input: $0) }
        )
    }
}
