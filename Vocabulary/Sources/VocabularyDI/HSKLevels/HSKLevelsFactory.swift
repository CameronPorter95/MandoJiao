import CoreDI
import DictionaryDomain
import VocabularyDomain
import VocabularyUI

/// Its only way out is being closed, which the library presenting it owns. Input is the
/// dictionary, which holds the syllabus.
public enum HSKLevelsFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input dictionary: DictionaryAccess) -> HSKLevelsRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return HSKLevelsRoute(viewModel: HSKLevelsViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getWords: GetHSKWordsUseCase(hsk: dictionary.hsk),
            installLevel: InstallHSKLevelUseCase(hsk: dictionary.hsk, repository: repository)
        ))
    }
}
