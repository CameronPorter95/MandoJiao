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
    private let dictionary = FakeDictionaryRepository()

    private func makeEditor(
        _ word: Word?,
        draft: WordDraft = WordDraft(),
        lexicon: FakeLexiconRepository? = nil,
        dictionary: FakeDictionaryRepository? = nil,
        suggestionDelay: Duration = .zero
    ) -> (WordEditorViewModel, EffectLog<WordEditorEffect>) {
        let viewModel = WordEditorViewModel(
            target: word.map(WordEditorTarget.edit) ?? .new(draft),
            saveWord: SaveWordUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            suggestWord: SuggestWordUseCase(repository: lexicon ?? self.lexicon),
            lookUpDictionary: LookUpDictionaryUseCase(repository: dictionary ?? self.dictionary),
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            suggestionDelay: suggestionDelay
        )
        return (viewModel, EffectLog(viewModel.effects()))
    }

    @Test("a new word needs a meaning and Hanzi, is saved trimmed, then closes")
    func newWord() async {
        let (editor, log) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        #expect(editor.state.title == "New word")
        #expect(!editor.state.canDelete)

        editor.send(.meaningAdded(" to drink "))
        #expect(!editor.state.canSave)
        editor.send(.hanziChanged("喝"))
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new to drink|喝|"])
    }

    @Test("a new word filled in from the dictionary opens with its reading and headline, and saves as new")
    func prefilledWord() async {
        let (editor, log) = makeEditor(nil, draft: WordDraft(english: "row, line", hanzi: "行", pinyin: "háng"))
        #expect(editor.state.title == "New word")
        #expect(!editor.state.canDelete)
        editor.send(.appeared)
        #expect(await waitUntil { !editor.state.entries.isEmpty })
        #expect(editor.state.meanings == ["row, line"])
        #expect(editor.state.pinyinSuggestion == nil)
        #expect(!editor.state.isCustom("row, line"))

        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new row, line|行|háng"])
    }

    @Test("an existing word opens filled in and saves under its own identity")
    func existingWord() async {
        let (editor, log) = makeEditor(Fixtures.water)
        #expect(editor.state.draft == WordDraft(english: "water", hanzi: "水", pinyin: "shuǐ"))
        #expect(editor.state.meanings == ["water"])
        #expect(editor.state.title == "Edit word")

        editor.send(.pinyinChanged("shui"))
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord existing water|水|shui"])
    }

    @Test("a new word is offered every deck, sectioned by folder in the tree's order, none chosen, and joins the one chosen")
    func choosingADeck() async throws {
        let (editor, log) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        editor.send(.appeared)
        #expect(await waitUntil { !editor.state.deckSections.isEmpty })
        #expect(editor.state.deckSections.map(\.title) == ["Starter"])
        #expect(editor.state.deckSections.first?.decks.map(\.name) == ["Full", "Small"])
        #expect(editor.state.chosenDeckID == nil)
        #expect(editor.state.chosenDeckTitle == "None")

        editor.send(.deckChosen(Fixtures.smallDeck.id))
        #expect(editor.state.chosenDeckTitle == "Starter › Small")
        editor.send(.meaningAdded("to drink"))
        editor.send(.hanziChanged("喝"))
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new to drink|喝| into Small"])
        let snapshot = await repository.snapshot
        let saved = try #require(snapshot.words.first { $0.hanzi == "喝" })
        #expect(snapshot.deck(id: Fixtures.smallDeck.id)?.wordIDs.last == saved.id)
    }

    @Test("decks named alike are told apart by their folder's section, nested folders after their parent, and empty folders left out")
    func deckSectionsNested() async {
        await repository.replace(Fixtures.nested)
        let (editor, _) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        editor.send(.appeared)
        #expect(await waitUntil { editor.state.deckSections.count == 2 })
        #expect(editor.state.deckSections.map(\.title) == ["Starter", "HSK › Level 1"])
        #expect(editor.state.deckSections.map { $0.decks.map(\.name) } == [["Full"], ["Part 1", "Part 2"]])

        editor.send(.deckChosen(Fixtures.part2.id))
        #expect(editor.state.chosenDeckTitle == "HSK › Level 1 › Part 2")
    }

    @Test("a deck deleted after it was chosen is no longer chosen, and the word joins no deck")
    func chosenDeckDeleted() async {
        let (editor, log) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        editor.send(.appeared)
        #expect(await waitUntil { !editor.state.deckSections.isEmpty })
        editor.send(.deckChosen(Fixtures.smallDeck.id))
        #expect(editor.state.chosenDeckID == Fixtures.smallDeck.id)

        var vocabulary = Fixtures.vocabulary
        vocabulary.decks.removeAll { $0.id == Fixtures.smallDeck.id }
        await repository.replace(vocabulary)
        #expect(await waitUntil { editor.state.deckSections.first?.decks.count == 1 })
        #expect(editor.state.chosenDeckID == nil)

        editor.send(.meaningAdded("to drink"))
        editor.send(.hanziChanged("喝"))
        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new to drink|喝|"])
    }

    @Test("a saved word is offered no decks, its decks being changed from each deck")
    func savedWordOffersNoDecks() async {
        let (editor, log) = makeEditor(Fixtures.water)
        editor.send(.appeared)
        #expect(await waitUntil { editor.state.lookup != nil })
        #expect(editor.state.deckSections.isEmpty)
        #expect(editor.state.vocabulary == .empty)

        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord existing water|水|shuǐ"])
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
        editor.send(.meaningAdded("tea"))
        editor.send(.hanziChanged("茶"))
        editor.send(.saveTapped)

        #expect(await log.contains(.showError(.saveWordFailed(FakeVocabularyRepository.failure))))
        #expect(!log.effects.contains(.dismiss))
        #expect(editor.state.meanings == ["tea"])
    }

    @Test("typing Hanzi suggests its first sense and that reading's pinyin, saved as shown")
    func suggested() async {
        let (editor, log) = makeEditor(nil)
        editor.send(.hanziChanged("喝"))

        #expect(await waitUntil { editor.state.meanings == ["to drink"] })
        #expect(editor.state.meaningsAreSuggested)
        #expect(editor.state.entries.map(\.pinyin) == ["hē", "hè"])
        #expect(editor.state.pinyinSuggestion == "hē")
        #expect(editor.state.canSave)
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new to drink|喝|hē"])
    }

    @Test("senses are saved as the dictionary writes them, asides and all")
    func sensesAsWritten() async {
        let (editor, log) = makeEditor(nil)
        editor.send(.hanziChanged("银行"))
        #expect(await waitUntil { editor.state.meanings == ["bank (CL:家[jia1],個|个[ge4])"] })
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new bank (CL:家[jia1],個|个[ge4])|银行|yínháng"])
    }

    @Test("ticking senses adds them in order, and unticking the last leaves none")
    func ticking() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.hanziChanged("喝"))
        #expect(await waitUntil { editor.state.meanings == ["to drink"] })

        editor.send(.senseToggled("to shout (of approval)"))
        #expect(editor.state.meanings == ["to drink", "to shout (of approval)"])
        #expect(!editor.state.meaningsAreSuggested)
        #expect(editor.state.isChosen("to shout (of approval)"))

        editor.send(.senseToggled("to drink"))
        editor.send(.senseToggled("to shout (of approval)"))
        #expect(editor.state.meanings.isEmpty)
        #expect(!editor.state.canSave)
    }

    @Test("pinyin follows the reading the headline comes from")
    func pinyinFollowsHeadline() async {
        let (editor, log) = makeEditor(nil, lexicon: FakeLexiconRepository([WordSuggestion(hanzi: "行", pinyin: "xíng", english: "to walk")]))
        editor.send(.hanziChanged("行"))
        #expect(await waitUntil { editor.state.pinyinSuggestion == "xíng" })

        editor.send(.senseToggled("to walk"))
        editor.send(.senseToggled("profession"))
        #expect(editor.state.pinyinSuggestion == "háng")

        editor.send(.meaningAdded("a custom one"))
        editor.send(.meaningsMoved(from: [1], to: 0))
        #expect(editor.state.isCustom("a custom one"))
        // Not a sense of either reading, so back to the lexicon's.
        #expect(editor.state.pinyinSuggestion == "xíng")

        editor.send(.meaningsRemoved([0]))
        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new profession|行|háng"])
    }

    @Test("meanings reorder, and a repeated custom meaning is not added twice")
    func editingMeanings() async {
        let (editor, _) = makeEditor(Word(meanings: ["to drink", "to shout"], hanzi: "喝"))
        editor.send(.meaningAdded("TO DRINK"))
        editor.send(.meaningAdded("  "))
        #expect(editor.state.meanings == ["to drink", "to shout"])

        editor.send(.meaningAdded("to sip"))
        editor.send(.meaningsMoved(from: [2], to: 0))
        #expect(editor.state.meanings == ["to sip", "to drink", "to shout"])
    }

    @Test("a new word starts with one field, the headline's, and another appears once it has one")
    func headlineFirst() async {
        let (editor, log) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        #expect(editor.state.meaningRows == [""])
        #expect(!editor.state.canAddMeaning)

        editor.send(.meaningEdited(at: 0, text: "t"))
        editor.send(.meaningEdited(at: 0, text: "tea "))
        #expect(editor.state.meaningRows == ["tea "])
        #expect(editor.state.canAddMeaning)

        editor.send(.meaningAdded("a drink"))
        editor.send(.meaningEdited(at: 1, text: ""))
        #expect(editor.state.meaningRows == ["tea ", ""])
        editor.send(.hanziChanged("茶"))
        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord new tea|茶|"])
    }

    @Test("editing the suggested headline makes it the user's, and a blank one is replaced by what is added")
    func editingSuggestion() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.hanziChanged("喝"))
        #expect(await waitUntil { editor.state.meanings == ["to drink"] })

        editor.send(.meaningEdited(at: 0, text: "to drink tea"))
        #expect(!editor.state.meaningsAreSuggested)
        #expect(editor.state.isCustom("to drink tea"))

        editor.send(.meaningEdited(at: 0, text: ""))
        #expect(!editor.state.canAddMeaning)
        editor.send(.senseToggled("to shout (of approval)"))
        #expect(editor.state.meanings == ["to shout (of approval)"])
    }

    @Test("untouched meanings follow the Hanzi, and touched ones stay put")
    func followsHanziUntilTouched() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.hanziChanged("银"))
        #expect(await waitUntil { editor.state.meanings == ["silver"] })

        editor.send(.hanziChanged("银行"))
        #expect(editor.state.meanings.isEmpty)
        #expect(editor.state.pinyinSuggestion == nil)
        #expect(!editor.state.canSave)
        #expect(await waitUntil { editor.state.meanings == ["bank (CL:家[jia1],個|个[ge4])"] })

        editor.send(.senseToggled("bank (financial institution)"))
        editor.send(.hanziChanged("银"))
        #expect(await waitUntil { await dictionary.lookups.last == "银" })
        await settle()
        #expect(editor.state.meanings == ["bank (CL:家[jia1],個|个[ge4])", "bank (financial institution)"])
    }

    @Test("an existing word keeps its own meanings over the dictionary's")
    func existingWordSuggestion() async {
        let word = Word(english: "a drink", hanzi: "喝")
        let (editor, log) = makeEditor(word)
        editor.send(.appeared)

        #expect(await waitUntil { editor.state.pinyinSuggestion == "hē" })
        #expect(editor.state.meanings == ["a drink"])
        #expect(!editor.state.meaningsAreSuggested)
        #expect(editor.state.isCustom("a drink"))
        editor.send(.saveTapped)

        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord existing a drink|喝|hē"])
    }

    @Test("only the Hanzi typing pauses on is looked up")
    func debounced() async {
        let (editor, _) = makeEditor(nil, suggestionDelay: .milliseconds(50))
        editor.send(.hanziChanged("银"))
        editor.send(.hanziChanged("银行"))

        #expect(await waitUntil { editor.state.pinyinSuggestion == "yínháng" })
        await settle()
        #expect(await lexicon.lookups == ["银行"])
        #expect(await dictionary.lookups == ["银行"])
    }

    @Test("a failed dictionary lookup still suggests the lexicon's pinyin, and shows no error")
    func failedDictionary() async {
        let (editor, log) = makeEditor(nil)
        await dictionary.failLookups()
        editor.send(.hanziChanged("喝"))

        #expect(await waitUntil { editor.state.pinyinSuggestion == "hē" })
        #expect(editor.state.entries.isEmpty)
        #expect(editor.state.meanings.isEmpty)
        #expect(log.effects.isEmpty)
    }

    @Test("a failed lexicon lookup still offers the dictionary, and shows no error")
    func failedLookup() async {
        let (editor, log) = makeEditor(nil)
        await lexicon.failLookups()
        editor.send(.hanziChanged("喝"))

        #expect(await waitUntil { editor.state.meanings == ["to drink"] })
        #expect(editor.state.pinyinSuggestion == "hē")
        await settle()
        #expect(log.effects.isEmpty)
    }

    @Test("blank Hanzi looks nothing up")
    func blankHanzi() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.appeared)
        editor.send(.hanziChanged("  "))

        await settle()
        #expect(await lexicon.lookups.isEmpty)
        #expect(await dictionary.lookups.isEmpty)
    }

    @Test("the dictionary opens on the Hanzi with the reading that would be saved")
    func dictionary() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.dictionaryTapped)
        #expect(editor.state.dictionary == nil)

        editor.send(.hanziChanged(" 行 "))
        #expect(await waitUntil { editor.state.pinyinSuggestion == "xíng" })
        editor.send(.senseToggled("to walk"))
        editor.send(.senseToggled("profession"))
        editor.send(.dictionaryTapped)
        #expect(editor.state.dictionary == DictionaryHeadword(hanzi: "行", pinyin: "háng"))

        editor.send(.dictionaryDismissed)
        #expect(editor.state.dictionary == nil)
    }

    @Test("a reading with no senses offers nothing to tick, nor the suggested meaning")
    func sensesless() async {
        let empty = FakeDictionaryRepository.entry("了", "liǎo", preferred: true)
        let le = FakeDictionaryRepository.entry("了", "le", preferred: false, "(completed action marker)")
        let (editor, _) = makeEditor(nil, dictionary: FakeDictionaryRepository([empty, le]))
        editor.send(.hanziChanged("了"))

        #expect(await waitUntil { editor.state.meanings == ["(completed action marker)"] })
        #expect(editor.state.tickableEntries.map(\.pinyin) == ["le"])
        #expect(editor.state.pinyinSuggestion == "le")
    }

    @Test("the dictionary's senses open apart from the word, and only when there are some")
    func choosingSenses() async {
        let (editor, _) = makeEditor(nil)
        editor.send(.hanziChanged("茶"))
        #expect(await waitUntil { await dictionary.lookups == ["茶"] })
        await settle()
        editor.send(.sensesTapped)
        #expect(!editor.state.isChoosingSenses)

        editor.send(.hanziChanged("喝"))
        #expect(await waitUntil { !editor.state.tickableEntries.isEmpty })
        editor.send(.sensesTapped)
        #expect(editor.state.isChoosingSenses)
        editor.send(.senseToggled("to shout (of approval)"))
        editor.send(.sensesDismissed)
        #expect(!editor.state.isChoosingSenses)
        #expect(editor.state.meanings == ["to drink", "to shout (of approval)"])
    }
}
