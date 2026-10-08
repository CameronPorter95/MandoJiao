import CoreDI
import CoreUI
import DictionaryDomain
import LibraryDomain
import LibraryUI

/// Its only way out is being closed, which the library presenting it owns. Input is the
/// dictionary, which holds the syllabus.
public enum HSKLevelsFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input dictionary: DictionaryAccess) -> HSKLevelsRoute {
        HSKLevelsRoute(viewModel: makeViewModel(dependencies: dependencies, dictionary: dictionary))
    }

    /// The levels without their view. `dismiss` closes the sheet, which the presenter owns.
    public static func makeDriver(
        dependencies: Dependencies,
        input dictionary: DictionaryAccess,
        dismiss: @escaping () -> Void
    ) -> ScreenDriver {
        makeViewModel(dependencies: dependencies, dictionary: dictionary).driver(dismiss: dismiss)
    }

    private static func makeViewModel(dependencies: Dependencies, dictionary: DictionaryAccess) -> HSKLevelsViewModel {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return HSKLevelsViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getWords: GetHSKWordsUseCase(hsk: dictionary.hsk),
            installLevel: InstallHSKLevelUseCase(hsk: dictionary.hsk, repository: repository)
        )
    }
}
