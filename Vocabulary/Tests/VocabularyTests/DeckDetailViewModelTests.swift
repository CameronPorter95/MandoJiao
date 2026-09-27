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
        #expect(!detail.state.canStartLesson)

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

    @Test("starting a lesson asks for one over the deck's words, under the typed name")
    func startingALesson() async {
        let (detail, log) = await makeDetail()
        detail.send(.nameChanged("Mixed"))
        detail.send(.startLessonTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .startLesson(let request) = log.effects.first else {
            Issue.record("expected a lesson request")
            return
        }
        #expect(request.title == "Mixed")
        #expect(request.pool.count == 5)
    }

    @Test("a deck below the matching floor cannot start")
    func tooSmall() async {
        let (detail, log) = await makeDetail(Fixtures.smallDeck)
        #expect(detail.state.selectedCount == 1)
        detail.send(.startLessonTapped)

        await settle()
        #expect(log.effects.isEmpty)
    }

    @Test("a deck shows where it lives, and moves into any folder or out to the top level")
    func moving() async {
        let (detail, _) = await makeDetail(Fixtures.part1, nested: true)
        #expect(detail.state.location == "HSK › Level 1")
        #expect(detail.state.destinations.map(\.title) == ["Top level", "Empty", "HSK"])

        detail.send(.moveTapped)
        #expect(detail.state.isChoosingDestination)
        detail.send(.destinationChosen(Fixtures.hsk.id))

        #expect(!detail.state.isChoosingDestination)
        #expect(detail.state.location == "HSK")
        #expect(await waitUntil { await nestedRepository.writes == ["moveDeck Part 1 to HSK"] })
    }

    @Test("a failed move puts the deck back and says why")
    func failedMove() async {
        let (detail, log) = await makeDetail(Fixtures.part1, nested: true)
        await nestedRepository.failWrites()
        detail.send(.destinationChosen(nil))
        #expect(detail.state.deck?.folderID == nil)

        #expect(await log.contains(.showError(.moveDeckFailed(FakeVocabularyRepository.failure))))
        #expect(detail.state.deck?.folderID == Fixtures.level1.id)
    }

    @Test("with no folder to move into, the deck says so")
    func nowhereToMove() async {
        let (detail, _) = await makeDetail()
        #expect(detail.state.location == "Top level")
        #expect(detail.state.destinations.isEmpty)
        #expect(detail.state.moveUnavailableReason == "Make a folder first to move this deck into.")

        let (nested, _) = await makeDetail(Fixtures.fullDeck, nested: true)
        #expect(nested.state.moveUnavailableReason == nil)
    }
}
