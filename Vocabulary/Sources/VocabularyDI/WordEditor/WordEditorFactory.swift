import CoreDI
import VocabularyDomain
import VocabularyUI

/// Input is the word to edit, or a new one to fill in.
public enum WordEditorFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input target: WordEditorTarget) -> WordEditorRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return WordEditorRoute(
            viewModel: WordEditorViewModel(
                target: target,
                saveWord: SaveWordUseCase(repository: repository),
                deleteWords: DeleteWordsUseCase(repository: repository),
                suggestWord: SuggestWordUseCase(repository: VocabularyRepositoryFactory.makeLexiconRepository()),
                lookUpDictionary: LookUpDictionaryUseCase(repository: VocabularyRepositoryFactory.makeDictionaryRepository()),
                observeVocabulary: ObserveVocabularyUseCase(repository: repository)
            ),
            // Adding from the dictionary would open an editor over this one.
            makeDictionary: { DictionaryFactory.makeRoute(dependencies: dependencies, input: DictionaryInput(headword: $0, addsToVocabulary: false)) }
        )
    }
}
