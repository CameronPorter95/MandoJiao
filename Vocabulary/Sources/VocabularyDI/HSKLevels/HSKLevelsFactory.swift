import CoreDI
import VocabularyDomain
import VocabularyUI

/// Its only way out is being closed, which the library presenting it owns.
public enum HSKLevelsFactory: RouteFactory {
    public static func makeRoute(dependencies: Dependencies) -> HSKLevelsRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        let hsk = VocabularyRepositoryFactory.makeHSKRepository()
        return HSKLevelsRoute(viewModel: HSKLevelsViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getWords: GetHSKWordsUseCase(hsk: hsk),
            installLevel: InstallHSKLevelUseCase(hsk: hsk, repository: repository)
        ))
    }
}
