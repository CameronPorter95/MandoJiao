import CoreDI
import CoreUI
import DictionaryDomain
import DictionaryUI

/// Input is the vocabulary any reading can be added to.
public enum DictionaryTabFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input vocabulary: DictionaryVocabulary) -> DictionaryTabRoute {
        let observe = ObserveSavedReadingsUseCase(repository: vocabulary.savedReadings)
        return DictionaryTabRoute(
            viewModel: makeSearch(observe: observe),
            makePage: makePage(observe: observe),
            makeEditor: vocabulary.editor
        )
    }

    /// The search without its view, searching as soon as the query changes, and the headword
    /// pages pushed over it. The editor a reading opens is not driven.
    public static func makeDriver(dependencies: Dependencies, input vocabulary: DictionaryVocabulary) -> ScreenDriver {
        let observe = ObserveSavedReadingsUseCase(repository: vocabulary.savedReadings)
        let makePage = makePage(observe: observe)
        return makeSearch(observe: observe, searchDelay: .zero).driver { headword, open in
            makePage(headword).driver(open: open)
        }
    }

    private static func makeSearch(
        observe: ObserveSavedReadingsUseCase,
        searchDelay: Duration = DictionarySearchViewModel.defaultSearchDelay
    ) -> DictionarySearchViewModel {
        DictionarySearchViewModel(
            searchDictionary: SearchDictionaryUseCase(repository: DictionaryRepositoryFactory.makeDictionaryRepository()),
            observeSaved: observe,
            searchDelay: searchDelay
        )
    }

    private static func makePage(observe: ObserveSavedReadingsUseCase) -> (DictionaryHeadword) -> DictionaryPageViewModel {
        let lookUp = LookUpDictionaryUseCase(repository: DictionaryRepositoryFactory.makeDictionaryRepository())
        return { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp, observeSaved: observe) }
    }
}
