import CoreDI
import CoreUI
import DictionaryDomain
import LibraryDomain
import LibraryUI
import SwiftUI

public enum WordEditorFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: WordEditorInput) -> WordEditorRoute {
        WordEditorRoute(
            viewModel: makeViewModel(dependencies: dependencies, input: input),
            // Adding from the dictionary would open an editor over this one.
            makeDictionary: { input.dictionary.page($0, false) }
        )
    }

    /// The editor without its view, looking the Hanzi up without waiting for typing to pause.
    /// `dismiss` closes the sheet, which the presenter owns.
    public static func makeDriver(
        dependencies: Dependencies,
        input: WordEditorInput,
        dismiss: @escaping () -> Void
    ) -> ScreenDriver {
        makeViewModel(dependencies: dependencies, input: input, suggestionDelay: .zero).driver(dismiss: dismiss)
    }

    private static func makeViewModel(
        dependencies: Dependencies,
        input: WordEditorInput,
        suggestionDelay: Duration = WordEditorViewModel.defaultSuggestionDelay
    ) -> WordEditorViewModel {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return WordEditorViewModel(
            target: input.target,
            saveWord: SaveWordUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            setLearnt: SetWordLearntUseCase(repository: repository),
            suggestWord: SuggestWordUseCase(repository: input.dictionary.lexicon),
            lookUpDictionary: LookUpDictionaryUseCase(repository: input.dictionary.dictionary),
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            suggestionDelay: suggestionDelay
        )
    }
}
