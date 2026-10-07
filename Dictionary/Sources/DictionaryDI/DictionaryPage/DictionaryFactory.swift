import CoreDI
import DictionaryDomain
import DictionaryUI

public enum DictionaryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: DictionaryInput) -> DictionaryRoute {
        let lookUp = LookUpDictionaryUseCase(repository: DictionaryRepositoryFactory.makeDictionaryRepository())
        let observe = input.vocabulary.map { ObserveSavedReadingsUseCase(repository: $0.savedReadings) }
        return DictionaryRoute(
            headword: input.headword,
            makeViewModel: { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp, observeSaved: observe) },
            makeEditor: input.vocabulary?.editor
        )
    }
}
