import CoreDI
import CoreUI
import LibraryDomain
import LibraryUI

public enum WordLibraryFactory: InputRouteFactory {
    public static func makeRoute(dependencies: Dependencies, input: WordLibraryInput) -> WordLibraryRoute {
        WordLibraryRoute(
            viewModel: makeViewModel(dependencies: dependencies, input: input),
            layout: input.layout,
            searchText: input.searchText,
            makeEditor: { WordEditorFactory.makeRoute(dependencies: dependencies, input: WordEditorInput(target: $0, dictionary: input.dictionary)) },
            makeDictionary: { input.dictionary.page($0, true) }
        )
    }

    /// The results without their view, with the word editor over them when a word is opened, and
    /// a word's dictionary page when the dictionary gives a driver for one.
    public static func makeDriver(dependencies: Dependencies, input: WordLibraryInput) -> ScreenDriver {
        makeViewModel(dependencies: dependencies, input: input).driver(
            layout: input.layout,
            editor: { target, dismissed in
                WordEditorFactory.makeDriver(
                    dependencies: dependencies,
                    input: WordEditorInput(target: target, dictionary: input.dictionary),
                    dismiss: dismissed
                )
            },
            page: input.dictionary.pageDriver.map { page in { page($0, true) } }
        )
    }

    private static func makeViewModel(dependencies: Dependencies, input: WordLibraryInput) -> WordLibraryViewModel {
        let repository = VocabularyRepositoryFactory.makeRepository(dependencies: dependencies)
        return WordLibraryViewModel(
            folderID: input.folderID,
            vocabulary: input.vocabulary,
            sort: input.layout.sort,
            searchText: input.searchText,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            setLearnt: SetWordLearntUseCase(repository: repository)
        )
    }
}
