import CoreDI
import DictionaryDomain
import SwiftUI
import VocabularyDomain
import VocabularyUI

public enum WordEditorFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: WordEditorInput) -> WordEditorRoute {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return WordEditorRoute(
            viewModel: WordEditorViewModel(
                target: input.target,
                saveWord: SaveWordUseCase(repository: repository),
                deleteWords: DeleteWordsUseCase(repository: repository),
                setLearnt: SetWordLearntUseCase(repository: repository),
                suggestWord: SuggestWordUseCase(repository: input.dictionary.lexicon),
                lookUpDictionary: LookUpDictionaryUseCase(repository: input.dictionary.dictionary),
                observeVocabulary: ObserveVocabularyUseCase(repository: repository)
            ),
            // Adding from the dictionary would open an editor over this one.
            makeDictionary: { input.dictionary.page($0, false) }
        )
    }
}
