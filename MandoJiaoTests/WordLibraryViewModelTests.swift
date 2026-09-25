import Foundation
import Testing
@testable import MandoJiao

@Suite("Word library")
@MainActor
struct WordLibraryViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)

    private func makeLibrary() async -> (WordLibraryViewModel, EffectLog<WordLibraryEffect>) {
        let viewModel = WordLibraryViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.vocabulary == Fixtures.vocabulary }
        return (viewModel, log)
    }

    @Test("words are listed alphabetically and filtered by the search")
    func searching() async {
        let (library, _) = await makeLibrary()
        #expect(library.state.words.first?.english == "")
        #expect(library.state.words.dropFirst().first?.english == "book")

        library.send(.searchChanged("sh"))
        #expect(library.state.filteredWords.map(\.english) == ["book", "water", "mobile phone"].sorted())
    }

    @Test("the editor opens on the chosen word, or blank for a new one")
    func editor() async {
        let (library, _) = await makeLibrary()
        library.send(.editTapped(Fixtures.tea.id))
        #expect(library.state.editor == .edit(Fixtures.tea))

        library.send(.editorDismissed)
        library.send(.addTapped)
        #expect(library.state.editor == .new)
    }

    @Test("deleting removes the word at once and from the store")
    func deleting() async {
        let (library, _) = await makeLibrary()
        library.send(.deleteTapped([Fixtures.tea.id]))

        #expect(!library.state.words.contains(Fixtures.tea))
        #expect(await waitUntil { await repository.writes == ["deleteWords 1"] })
    }

    @Test("a failed delete puts the word back and says why")
    func failedDelete() async {
        let (library, log) = await makeLibrary()
        await repository.failWrites()

        library.send(.deleteTapped([Fixtures.tea.id]))

        #expect(await log.contains(.showError(.deleteWordsFailed(FakeVocabularyRepository.failure))))
        #expect(library.state.words.contains(Fixtures.tea))
    }
}
