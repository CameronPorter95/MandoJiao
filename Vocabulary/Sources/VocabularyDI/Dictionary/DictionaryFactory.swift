import CoreDI
import VocabularyDomain
import VocabularyUI

public enum DictionaryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: DictionaryInput) -> DictionaryRoute {
        let lookUp = LookUpDictionaryUseCase(repository: VocabularyRepositoryFactory.makeDictionaryRepository())
        let observe = input.addsToVocabulary
            ? ObserveVocabularyUseCase(repository: VocabularyRepositoryFactory.makeRepository(dependencies: dependencies))
            : nil
        return DictionaryRoute(
            headword: input.headword,
            makeViewModel: { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp, observeVocabulary: observe) },
            makeEditor: input.addsToVocabulary ? { WordEditorFactory.makeRoute(dependencies: dependencies, input: $0) } : nil
        )
    }
}
