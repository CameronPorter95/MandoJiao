import CoreDI
import CoreUI
import DictionaryDomain
import DictionaryUI

public enum DictionaryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: DictionaryInput) -> DictionaryRoute {
        DictionaryRoute(
            headword: input.headword,
            makeViewModel: makePage(input: input),
            makeEditor: input.vocabulary?.editor
        )
    }

    /// The page without its view. Its characters' pages, pushed in the view's own stack, are not.
    public static func makeDriver(dependencies: Dependencies, input: DictionaryInput) -> ScreenDriver {
        makePage(input: input)(input.headword).driver(open: nil, editor: input.vocabulary?.editorDriver)
    }

    private static func makePage(input: DictionaryInput) -> (DictionaryHeadword) -> DictionaryPageViewModel {
        let lookUp = LookUpDictionaryUseCase(repository: DictionaryRepositoryFactory.makeDictionaryRepository())
        let observe = input.vocabulary.map { ObserveSavedReadingsUseCase(repository: $0.savedReadings) }
        return { DictionaryPageViewModel(headword: $0, lookUpDictionary: lookUp, observeSaved: observe) }
    }
}
