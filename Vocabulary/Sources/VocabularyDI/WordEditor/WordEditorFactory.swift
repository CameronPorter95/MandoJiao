import CoreDI
import VocabularyDomain
import VocabularyUI

/// Input is the word to edit, or nil for a new one.
public enum WordEditorFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input word: Word?) -> WordEditorRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return WordEditorRoute(
            viewModel: WordEditorViewModel(
                word: word,
                saveWord: SaveWordUseCase(repository: repository),
                deleteWords: DeleteWordsUseCase(repository: repository),
                suggestWord: SuggestWordUseCase(repository: VocabularyRepositoryFactory.makeLexiconRepository()),
                lookUpDictionary: LookUpDictionaryUseCase(repository: VocabularyRepositoryFactory.makeDictionaryRepository())
            )
        )
    }
}
