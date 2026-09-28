import CoreDI
import VocabularyDomain
import VocabularyUI

public enum DictionaryTabFactory: RouteFactory {
    public static func makeRoute(dependencies: Dependencies) -> DictionaryTabRoute {
        let repository = VocabularyRepositoryFactory.makeDictionaryRepository()
        let lookUp = LookUpDictionaryUseCase(repository: repository)
        return DictionaryTabRoute(
            viewModel: DictionarySearchViewModel(searchDictionary: SearchDictionaryUseCase(repository: repository)),
            makePage: { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp) }
        )
    }
}
