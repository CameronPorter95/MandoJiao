import CoreDI
import VocabularyDomain
import VocabularyUI

/// Input is the headword to open on.
public enum DictionaryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input headword: DictionaryHeadword) -> DictionaryRoute {
        let lookUp = LookUpDictionaryUseCase(repository: VocabularyRepositoryFactory.makeDictionaryRepository())
        return DictionaryRoute(headword: headword) {
            DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp)
        }
    }
}
