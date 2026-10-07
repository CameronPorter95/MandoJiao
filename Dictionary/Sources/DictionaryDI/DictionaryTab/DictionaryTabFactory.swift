import CoreDI
import DictionaryDomain
import DictionaryUI

/// Input is the vocabulary any reading can be added to.
public enum DictionaryTabFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input vocabulary: DictionaryVocabulary) -> DictionaryTabRoute {
        let repository = DictionaryRepositoryFactory.makeDictionaryRepository()
        let lookUp = LookUpDictionaryUseCase(repository: repository)
        let observe = ObserveSavedReadingsUseCase(repository: vocabulary.savedReadings)
        return DictionaryTabRoute(
            viewModel: DictionarySearchViewModel(searchDictionary: SearchDictionaryUseCase(repository: repository), observeSaved: observe),
            makePage: { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp, observeSaved: observe) },
            makeEditor: vocabulary.editor
        )
    }
}
