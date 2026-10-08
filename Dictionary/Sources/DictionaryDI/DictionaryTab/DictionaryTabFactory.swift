import CoreDI
import CoreUI
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

    /// The search without its view, searching as soon as the query changes.
    public static func makeDriver(dependencies: Dependencies, input vocabulary: DictionaryVocabulary) -> ScreenDriver {
        let repository = DictionaryRepositoryFactory.makeDictionaryRepository()
        return DictionarySearchViewModel(
            searchDictionary: SearchDictionaryUseCase(repository: repository),
            observeSaved: ObserveSavedReadingsUseCase(repository: vocabulary.savedReadings),
            searchDelay: .zero
        ).driver()
    }
}
