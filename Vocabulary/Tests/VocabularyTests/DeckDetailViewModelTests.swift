import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

@Suite("Deck detail")
@MainActor
struct DeckDetailViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)

    private let nestedRepository = FakeVocabularyRepository(Fixtures.nested)

    private func makeDetail(
        _ deck: DeckSummary = Fixtures.fullDeck,
        nested: Bool = false
    ) async -> (DeckDetailViewModel, EffectLog<DeckDetailEffect>) {
        let repository = nested ? nestedRepository : repository
        let viewModel = DeckDetailViewModel(
            deckID: deck.id,
            minimumMatchingWords: 5,
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            renameDeck: RenameDeckUseCase(repository: repository),
            setMembership: SetDeckMembershipUseCase(repository: repository),
            moveDeck: MoveDeckUseCase(repository: repository),
            renameDelay: .milliseconds(30)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.name != nil }
        return (viewModel, log)
    }

    @Test("the name loads once and is not overwritten while typing")
    func name() async {
        let (detail, _) = await makeDetail()
        #expect(detail.state.name == "Full")

        detail.send(.nameChanged("Ful"))
        await repository.replace(Fixtures.vocabulary)
        await settle()

        #expect(detail.state.name == "Ful")
    }

    @Test("typing saves the name once it settles, not on every keystroke")
    func debouncedRename() async {
        let (detail, _) = await makeDetail()
        for name in ["F", "Fr", "Fru", "Fruit"] { detail.send(.nameChanged(name)) }

        #expect(await waitUntil { await repository.writes == ["renameDeck Fruit"] })
        await settle()
        #expect(await repository.writes == ["renameDeck Fruit"])
    }

    @Test("leaving saves a name that has not settled yet")
    func renameOnLeaving() async {
        let (detail, _) = await makeDetail()
        detail.send(.nameChanged("Fruit"))
        detail.send(.disappeared)

        #expect(await waitUntil { await repository.writes == ["renameDeck Fruit"] })
    }

    @Test("toggling a word changes the deck at once, and rapid toggles land in order")
    func toggling() async {
        let (detail, _) = await makeDetail()
        detail.send(.wordToggled(Fixtures.water.id))
        #expect(!detail.state.isIncluded(Fixtures.water.id))
        #expect(!detail.state.canStart(.matching))

        detail.send(.wordToggled(Fixtures.water.id))
        detail.send(.wordToggled(Fixtures.water.id))

        #expect(await waitUntil { await repository.writes.count == 3 })
        #expect(await repository.writes == ["setMembership false", "setMembership true", "setMembership false"])
        #expect(await waitUntil { await repository.snapshot.deck(id: Fixtures.fullDeck.id)?.wordIDs.contains(Fixtures.water.id) == false })
    }

    @Test("a failed toggle is undone and explained")
    func failedToggle() async {
        let (detail, log) = await makeDetail()
        await repository.failWrites()

        detail.send(.wordToggled(Fixtures.water.id))

        #expect(await log.contains(.showError(.updateDeckFailed(FakeVocabularyRepository.failure))))
        #expect(detail.state.isIncluded(Fixtures.water.id))
    }

    @Test("the deck lists only its own words, searched apart from the sheet that adds them")
    func ownWords() async {
        let (detail, _) = await makeDetail(Fixtures.smallDeck)
        // Small holds water and a word with no English, which sorts first as the list of all words does.
        #expect(detail.state.words.map(\.hanzi) == ["空", "水"])
        #expect(detail.state.wordCount == 2)
        #expect(detail.state.pickerWords.count == Fixtures.words.count)

        detail.send(.searchChanged("shui"))
        #expect(detail.state.words.map(\.english) == ["water"])
        #expect(detail.state.pickerWords.count == Fixtures.words.count)

        detail.send(.pickerSearchChanged("cha"))
        #expect(detail.state.pickerWords.map(\.english) == ["tea"])
        #expect(detail.state.words.map(\.english) == ["water"])
    }

    @Test("adding words opens a sheet with its search cleared, where a tap puts a word in the deck")
    func addingWords() async {
        let (detail, _) = await makeDetail(Fixtures.smallDeck)
        detail.send(.addWordsTapped)
        detail.send(.pickerSearchChanged("cha"))
        detail.send(.wordToggled(Fixtures.tea.id))
        #expect(detail.state.isIncluded(Fixtures.tea.id))
        #expect(detail.state.words.map(\.english).contains("tea"))
        #expect(await waitUntil { await repository.writes == ["setMembership true"] })

        detail.send(.addWordsDismissed)
        #expect(!detail.state.isAddingWords)
        detail.send(.addWordsTapped)
        #expect(detail.state.isAddingWords)
        #expect(detail.state.pickerSearchText == "")
    }

    @Test("removing takes a word out of the deck, leaves it in the library, and a repeat writes nothing")
    func removing() async {
        let (detail, _) = await makeDetail()
        detail.send(.removeTapped(Fixtures.water.id))
        detail.send(.removeTapped(Fixtures.water.id))
        #expect(!detail.state.words.contains(Fixtures.water))
        #expect(detail.state.vocabulary.words.contains(Fixtures.water))
        #expect(!detail.state.canStart(.matching))

        await settle()
        #expect(await repository.writes == ["setMembership false"])
    }

    @Test("a failed removal puts the word back and says why")
    func failedRemoval() async {
        let (detail, log) = await makeDetail()
        await repository.failWrites()

        detail.send(.removeTapped(Fixtures.water.id))

        #expect(await log.contains(.showError(.updateDeckFailed(FakeVocabularyRepository.failure))))
        #expect(detail.state.words.contains(Fixtures.water))
    }

    @Test("starting a lesson asks for one over the deck's words, under the typed name")
    func startingALesson() async {
        let (detail, log) = await makeDetail()
        detail.send(.nameChanged("Mixed"))
        detail.send(.startLessonTapped(.matching))

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .startLesson(let request, .matching) = log.effects.first else {
            Issue.record("expected a lesson request")
            return
        }
        #expect(request.title == "Mixed")
        #expect(request.pool.count == 5)
    }

    @Test("a deck below the matching floor cannot match, but can start flash cards or reading aloud")
    func tooSmall() async {
        let (detail, log) = await makeDetail(Fixtures.smallDeck)
        #expect(detail.state.selectedCount == 1)
        #expect(!detail.state.canStart(.matching))
        #expect(detail.state.canStart(.flashcards))
        #expect(detail.state.canStart(.speaking))
        detail.send(.startLessonTapped(.matching))
        await settle()
        #expect(log.effects.isEmpty)

        detail.send(.startLessonTapped(.flashcards))
        detail.send(.startLessonTapped(.speaking))
        #expect(await waitUntil { log.effects.count == 2 })
        let exercises = log.effects.compactMap { effect -> LessonExercise? in
            if case .startLesson(_, let exercise) = effect { exercise } else { nil }
        }
        #expect(exercises == [.flashcards, .speaking])
    }

    @Test("a deck moves into any other folder, never to the top level")
    func moving() async {
        let (detail, _) = await makeDetail(Fixtures.part1, nested: true)
        #expect(detail.state.destinations.map(\.title) == ["Empty", "HSK", "Starter"])

        detail.send(.moveTapped)
        #expect(detail.state.isChoosingDestination)
        detail.send(.destinationChosen(Fixtures.hsk.id))

        #expect(!detail.state.isChoosingDestination)
        #expect(detail.state.deck?.folderID == Fixtures.hsk.id)
        #expect(await waitUntil { await nestedRepository.writes == ["moveDeck Part 1 to HSK"] })
    }

    @Test("a failed move puts the deck back and says why")
    func failedMove() async {
        let (detail, log) = await makeDetail(Fixtures.part1, nested: true)
        await nestedRepository.failWrites()
        detail.send(.destinationChosen(Fixtures.hsk.id))
        #expect(detail.state.deck?.folderID == Fixtures.hsk.id)

        #expect(await log.contains(.showError(.moveDeckFailed(FakeVocabularyRepository.failure))))
        #expect(detail.state.deck?.folderID == Fixtures.level1.id)
    }

    @Test("with no folder to move into, the deck says so")
    func nowhereToMove() async {
        let (detail, _) = await makeDetail()
        #expect(detail.state.destinations.isEmpty)
        #expect(detail.state.moveUnavailableReason == "Make a folder first to move this deck into.")

        let (nested, _) = await makeDetail(Fixtures.fullDeck, nested: true)
        #expect(nested.state.moveUnavailableReason == nil)
    }
}
