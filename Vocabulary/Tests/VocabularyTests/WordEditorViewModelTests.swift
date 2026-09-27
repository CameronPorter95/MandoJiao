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
    private let lexicon = FakeLexiconRepository()

    private func makeEditor(
        _ word: Word?,
        lexicon: FakeLexiconRepository? = nil,
        suggestionDelay: Duration = .zero
    ) -> (WordEditorViewModel, EffectLog<WordEditorEffect>) {
        let viewModel = WordEditorViewModel(
            word: word,
            saveWord: SaveWordUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            suggestWord: SuggestWordUseCase(repository: lexicon ?? self.lexicon),
            suggestionDelay: suggestionDelay
        )
        return (viewModel, EffectLog(viewModel.effects()))
    }

    @Test("a new word needs English and Hanzi, is saved trimmed, then closes")
    func newWord() async {
        let (editor, log) = makeEditor(nil, lexicon: FakeLexiconRepository([]))
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

    @Test("typing Hanzi suggests pinyin and English, and saves them as shown")
    func suggested() async {
        let (editor, log) = makeEditor(nil)
        editor.send(.hanziChanged("喝"))

        #expect(await waitUntil { editor.state.englishSuggestion == "to drink" })
        #expect(editor.state.pinyinSuggestion == "hē")
        #expect(editor.state.canSave)
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new to drink|喝|hē"])
    }

    @Test("a typed field replaces its suggestion")
    func typedOver() async {
        let (editor, log) = makeEditor(nil)
        editor.send(.hanziChanged("银行"))
        #expect(await waitUntil { editor.state.englishSuggestion == "bank" })

        editor.send(.englishChanged("a bank"))
        #expect(editor.state.englishSuggestion == nil)
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new a bank|银行|yínháng"])
    }

    @Test("a suggestion for Hanzi since changed is neither shown nor saved")
    func staleSuggestion() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.hanziChanged("银"))
        #expect(await waitUntil { editor.state.englishSuggestion == "silver" })

        editor.send(.hanziChanged("银行"))
        #expect(editor.state.englishSuggestion == nil)
        #expect(editor.state.pinyinSuggestion == nil)
        #expect(!editor.state.canSave)

        #expect(await waitUntil { editor.state.englishSuggestion == "bank" })
    }

    @Test("only the Hanzi typing pauses on is looked up")
    func debounced() async {
        let (editor, _) = makeEditor(nil, suggestionDelay: .milliseconds(50))
        editor.send(.hanziChanged("银"))
        editor.send(.hanziChanged("银行"))

        #expect(await waitUntil { editor.state.englishSuggestion == "bank" })
        await settle()
        #expect(await lexicon.lookups == ["银行"])
    }

    @Test("an existing word keeps its own fields, and an empty one takes the suggestion")
    func existingWordSuggestion() async {
        let word = Word(english: "water", hanzi: "水")
        let (editor, log) = makeEditor(word)
        editor.send(.appeared)

        #expect(await waitUntil { editor.state.pinyinSuggestion == "shuǐ" })
        #expect(editor.state.englishSuggestion == nil)
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord existing water|水|shuǐ"])
    }

    @Test("a failed lookup is not shown as an error and leaves the fields to be typed")
    func failedLookup() async {
        let (editor, log) = makeEditor(nil)
        await lexicon.failLookups()
        editor.send(.hanziChanged("喝"))

        #expect(await waitUntil { await lexicon.lookups == ["喝"] })
        await settle()
        #expect(log.effects.isEmpty)
        #expect(editor.state.suggestion == nil)
        #expect(!editor.state.canSave)
    }

    @Test("blank Hanzi looks nothing up")
    func blankHanzi() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.appeared)
        editor.send(.hanziChanged("  "))

        await settle()
        #expect(await lexicon.lookups.isEmpty)
    }
}
