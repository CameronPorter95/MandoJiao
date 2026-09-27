import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

@Suite("Word editor")
@MainActor
struct WordEditorViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)

    private func makeEditor(_ word: Word?) -> (WordEditorViewModel, EffectLog<WordEditorEffect>) {
        let viewModel = WordEditorViewModel(
            word: word,
            saveWord: SaveWordUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository)
        )
        return (viewModel, EffectLog(viewModel.effects()))
    }

    @Test("a new word needs English and Hanzi, is saved trimmed, then closes")
    func newWord() async {
        let (editor, log) = makeEditor(nil)
        #expect(editor.state.title == "New word")
        #expect(!editor.state.canDelete)

        editor.send(.englishChanged(" to drink "))
        #expect(!editor.state.canSave)
        editor.send(.hanziChanged("喝"))
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new to drink|喝|"])
    }

    @Test("an existing word opens filled in and saves under its own identity")
    func existingWord() async {
        let (editor, log) = makeEditor(Fixtures.water)
        #expect(editor.state.draft == WordDraft(english: "water", hanzi: "水", pinyin: "shuǐ"))
        #expect(editor.state.title == "Edit word")

        editor.send(.pinyinChanged("shui"))
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord existing water|水|shui"])
    }

    @Test("deleting removes the word and closes")
    func deleting() async {
        let (editor, log) = makeEditor(Fixtures.water)
        editor.send(.deleteTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["deleteWords 1"])
    }

    @Test("a failed save stays open, keeping what was typed")
    func failedSave() async {
        let (editor, log) = makeEditor(nil)
        await repository.failWrites()
        editor.send(.englishChanged("tea"))
        editor.send(.hanziChanged("茶"))
        editor.send(.saveTapped)

        #expect(await log.contains(.showError(.saveWordFailed(FakeVocabularyRepository.failure))))
        #expect(!log.effects.contains(.dismiss))
        #expect(editor.state.draft.english == "tea")
    }
}
