import DictionaryDomain
import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import CoreUI
import DictionaryTestSupport
import LibraryTestSupport
@testable import LibraryDomain
@testable import LibraryData
@testable import LibraryUI

@Suite("Word editor")
@MainActor
struct WordEditorViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)
    private let lexicon = FakeLexiconRepository()
    private let dictionary = FakeDictionaryRepository()

    private func makeEditor(
        _ word: Word?,
        draft: WordDraft = WordDraft(),
        target: WordEditorTarget? = nil,
        lexicon: FakeLexiconRepository? = nil,
        dictionary: FakeDictionaryRepository? = nil,
        suggestionDelay: Duration = .zero
    ) -> (WordEditorViewModel, EffectLog<WordEditorEffect>) {
        let viewModel = WordEditorViewModel(
            target: target ?? word.map(WordEditorTarget.edit) ?? .new(draft),
            saveWord: SaveWordUseCase(repository: repository),
            deleteWords: DeleteWordsUseCase(repository: repository),
            setLearnt: SetWordLearntUseCase(repository: repository),
            suggestWord: SuggestWordUseCase(repository: lexicon ?? self.lexicon),
            lookUpDictionary: LookUpDictionaryUseCase(repository: dictionary ?? self.dictionary),
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            suggestionDelay: suggestionDelay
        )
        return (viewModel, EffectLog(viewModel.effects()))
    }

    @Test("driven by name, every listed action is accepted")
    func driverAcceptsEveryAction() {
        let arguments = [
            "hanziChanged": #"{"text":"喝"}"#, "pinyinChanged": #"{"text":"he"}"#, "senseToggled": #"{"sense":"to drink"}"#,
            "meaningAdded": #"{"text":"to drink"}"#, "meaningEdited": #"{"at":0,"text":"drink"}"#,
            "meaningMoved": #"{"from":0,"to":1}"#, "meaningRemoved": #"{"at":0}"#, "deckChosen": #"{"deck":null}"#,
            "deckSectionToggled": #"{"section":"none"}"#, "learntToggled": #"{"isLearnt":true}"#,
        ]
        for name in ["appeared", "disappeared", "hanziChanged", "pinyinChanged", "senseToggled", "meaningAdded",
                     "meaningEdited", "meaningMoved", "meaningRemoved", "sensesTapped", "sensesDismissed",
                     "dictionaryTapped", "dictionaryDismissed", "deckChosen", "deckSectionToggled", "saveTapped",
                     "learntToggled", "deleteTapped", "cancelTapped"] {
            let (editor, _) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
            let driver = editor.driver(dismiss: {})
            #expect(driver.actions.contains(name))
            #expect(throws: Never.self) { try driver.send(name, arguments[name].map { Data($0.utf8) }) }
        }
    }

    @Test("driven, a new word is typed, put in a deck by name, and saved, which closes the sheet")
    func driverAddsAWord() async throws {
        var dismissed = 0
        let (editor, _) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        let driver = editor.driver(dismiss: { dismissed += 1 })
        let effects = EffectLog(driver.effects())
        try driver.send("appeared", nil)
        #expect(await waitUntil { !editor.state.vocabulary.decks.isEmpty })

        try driver.send("hanziChanged", Data(#"{"text":"喝"}"#.utf8))
        try driver.send("meaningAdded", Data(#"{"text":"to drink"}"#.utf8))
        try driver.send("deckChosen", Data(#"{"deck":"\#(Fixtures.fullDeck.name.lowercased())"}"#.utf8))
        #expect(await waitUntil { !driver.isBusy() })
        let summary = driver.summary()
        #expect(summary.contains("hanzi: 喝  pinyin:   meanings: 0. to drink"))
        #expect(summary.contains("deck: \(editor.state.chosenDeckTitle)  can save"))
        #expect(editor.state.chosenDeckID == Fixtures.fullDeck.id)

        try driver.send("saveTapped", nil)
        #expect(await waitUntil { dismissed == 1 })
        #expect(effects.effects.isEmpty)
        #expect(await repository.writes == ["saveWord new to drink|喝| into \(Fixtures.fullDeck.name)"])
    }

    @Test("driven, a meaning's place past the end is ignored rather than trapping")
    func driverMeaningOutOfRange() throws {
        let (editor, _) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        let driver = editor.driver(dismiss: {})
        try driver.send("meaningAdded", Data(#"{"text":"to drink"}"#.utf8))
        try driver.send("meaningAdded", Data(#"{"text":"to swallow"}"#.utf8))

        try driver.send("meaningRemoved", Data(#"{"at":5}"#.utf8))
        try driver.send("meaningMoved", Data(#"{"from":5,"to":0}"#.utf8))
        try driver.send("meaningMoved", Data(#"{"from":0,"to":9}"#.utf8))
        #expect(editor.state.meanings == ["to drink", "to swallow"])

        try driver.send("meaningMoved", Data(#"{"from":1,"to":0}"#.utf8))
        try driver.send("meaningRemoved", Data(#"{"at":1}"#.utf8))
        #expect(editor.state.meanings == ["to swallow"])
    }

    @Test("driven, a deck nothing matches leaves the choice as it was, and back cancels")
    func driverUnknownDeckAndBack() async throws {
        var dismissed = 0
        let (editor, _) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        let driver = editor.driver(dismiss: { dismissed += 1 })
        let effects = EffectLog(driver.effects())
        try driver.send("deckChosen", Data(#"{"deck":"nope"}"#.utf8))
        #expect(editor.state.deckID == nil)

        #expect(driver.back())
        #expect(await waitUntil { dismissed == 1 })
        // Followed, so it never reaches the effects as a dismissal.
        #expect(effects.effects.isEmpty)
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

    @Test("a folder's section of decks folds and unfolds on its own, keeping the deck chosen")
    func foldingDeckSections() async {
        await repository.replace(Fixtures.nested)
        let (editor, _) = makeEditor(nil, lexicon: FakeLexiconRepository([]), dictionary: FakeDictionaryRepository([]))
        editor.send(.appeared)
        #expect(await waitUntil { editor.state.deckSections.count == 2 })
        #expect(editor.state.foldedDeckSections.isEmpty)
        editor.send(.deckChosen(Fixtures.part1.id))
        let level1 = editor.state.deckSections[1].id

        editor.send(.deckSectionToggled(level1))
        #expect(editor.state.foldedDeckSections == [level1])
        #expect(editor.state.chosenDeckID == Fixtures.part1.id)

        editor.send(.deckSectionToggled(level1))
        #expect(editor.state.foldedDeckSections.isEmpty)
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

    @Test("a saved word's learnt mark is set on Save, with the rest, and left alone if it did not change")
    func learnt() async {
        let (editor, log) = makeEditor(Fixtures.water)
        #expect(!editor.state.isLearnt)
        editor.send(.learntToggled(true))
        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes == ["saveWord existing water|水|shuǐ", "setLearnt true"])

        let (unchanged, unchangedLog) = makeEditor(Fixtures.tea)
        unchanged.send(.saveTapped)
        #expect(await unchangedLog.contains(.dismiss))
        #expect(await repository.writes.last == "saveWord existing tea|茶|chá")
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

    @Test("driven, the dictionary page is in front while open, and back closes it before the editor")
    func driverDictionaryPage() async throws {
        var dismissed = 0
        let (editor, _) = makeEditor(nil)
        let driver = editor.driver(dismiss: { dismissed += 1 }, page: { headword in
            ScreenDriver(
                name: "page \(headword.hanzi)", actions: [], state: { 0 }, summary: { _ in "" },
                send: { (_: Int) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
            )
        })
        try driver.send("hanziChanged", Data(#"{"text":"行"}"#.utf8))
        #expect(await waitUntil { !driver.isBusy() })

        try driver.send("dictionaryTapped", nil)
        #expect(driver.front()?.name == "page 行")
        #expect(driver.back())
        #expect(editor.state.dictionary == nil)
        #expect(driver.front() == nil)
        #expect(dismissed == 0)
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

    @Test("a saved word opened from the dictionary by its id is read in, then edits as any saved word")
    func savedByID() async throws {
        let word = try #require(Fixtures.vocabulary.words.first)
        let (editor, log) = makeEditor(nil, target: .saved(word.id))
        #expect(editor.state.isLoading)
        #expect(!editor.state.canSave)

        editor.send(.appeared)
        #expect(await waitUntil { !editor.state.isLoading })
        #expect(editor.state.title == "Edit word")
        #expect(editor.state.draft.hanzi == word.hanzi)
        #expect(editor.state.meanings == word.meanings)
        #expect(editor.state.canDelete)
        #expect(editor.state.deckSections.isEmpty)

        editor.send(.saveTapped)
        #expect(await log.contains(.dismiss))
        #expect(await repository.writes.first?.hasPrefix("saveWord existing") == true)
    }

    @Test("a saved word deleted before its editor opened closes the editor")
    func savedByIDDeleted() async {
        let (editor, log) = makeEditor(nil, target: .saved(UUID()))
        editor.send(.appeared)
        #expect(await log.contains(.dismiss))
    }

    @Test("a dictionary reading not saved becomes a new word with its first sense, or none, and a saved one opens by id")
    func targetFromReading() {
        let walk = FakeDictionaryRepository.entry("行", "xíng", preferred: true, "to walk", "okay")
        #expect(WordEditorTarget(.add(walk)) == .new(WordDraft(meanings: ["to walk"], hanzi: "行", pinyin: "xíng")))
        let yu = FakeDictionaryRepository.entry("于", "Yú", preferred: true)
        #expect(WordEditorTarget(.add(yu)) == .new(WordDraft(meanings: [], hanzi: "于", pinyin: "Yú")))
        let saved = SavedReading(id: UUID(), hanzi: "行", pinyin: "háng")
        #expect(WordEditorTarget(.open(saved)) == .saved(saved.id))
    }
}
