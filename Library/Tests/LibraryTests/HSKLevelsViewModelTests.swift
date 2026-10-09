import DictionaryDomain
import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import CoreUI
import DictionaryTestSupport
import LibraryTestSupport
@testable import LibraryDomain
@testable import LibraryUI

@Suite("HSK levels")
@MainActor
struct HSKLevelsViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)
    private let hsk = FakeHSKRepository()

    private func makeLevels() async -> (HSKLevelsViewModel, EffectLog<HSKLevelsEffect>) {
        let viewModel = HSKLevelsViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getWords: GetHSKWordsUseCase(hsk: hsk),
            installLevel: InstallHSKLevelUseCase(hsk: hsk, repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.words != nil }
        return (viewModel, log)
    }

    private func status(_ levels: HSKLevelsViewModel, _ level: Int) -> HSKLevelsState.Level.Status? {
        levels.state.levels.first { $0.level == level }?.status
    }

    @Test("driven by name, every listed action is accepted")
    func driverAcceptsEveryAction() async {
        for name in HSKLevelsAction.names {
            let (levels, _) = await makeLevels()
            let driver = levels.driver(dismiss: {})
            #expect(throws: Never.self) { try driver.send(name, name == "installTapped" ? Data(#"{"level":1}"#.utf8) : nil) }
        }
    }

    @Test("driven, a level is installed by its number, and back closes the sheet rather than reaching the effects")
    func driverInstallsAndCloses() async throws {
        var dismissed = 0
        let (levels, _) = await makeLevels()
        let driver = levels.driver(dismiss: { dismissed += 1 })
        let effects = EffectLog(driver.effects())
        #expect(driver.summary().contains("level 1: HSK 1 not added, 2 decks, 60 words"))

        try driver.send("installTapped", Data(#"{"level":1}"#.utf8))
        #expect(driver.isBusy())
        #expect(await waitUntil { status(levels, 1) == .added })
        #expect(await waitUntil { !driver.isBusy() })
        #expect(driver.summary().contains("level 1: HSK 1 added"))

        #expect(driver.back())
        #expect(await waitUntil { dismissed == 1 })
        await settle()
        #expect(effects.effects.isEmpty)
    }

    @Test("every level is listed with its size, none added yet")
    func listing() async {
        let (levels, _) = await makeLevels()
        let first = levels.state.levels.first
        #expect(levels.state.levels.map(\.level) == Array(HSK.levels))
        #expect(first?.wordCount == 60)
        #expect(first?.deckCount == 2)
        #expect(status(levels, 1) == .notAdded)
    }

    @Test("adding a level installs its decks, and it then shows as added")
    func adding() async {
        let (levels, _) = await makeLevels()
        levels.send(.installTapped(level: 1))

        #expect(await waitUntil { await repository.writes == ["install 2 decks"] })
        #expect(await waitUntil { self.status(levels, 1) == .added })
        #expect(levels.state.installing.isEmpty)
    }

    @Test("a level with a deleted deck offers to restore just that many")
    func restoring() async {
        let (levels, _) = await makeLevels()
        levels.send(.installTapped(level: 1))
        #expect(await waitUntil { self.status(levels, 1) == .added })

        let deck = await repository.snapshot.decks.first { $0.builtInKey == HSK.deckKey(1, 2) }!
        try? await repository.deleteDeck(id: deck.id)
        #expect(await waitUntil { self.status(levels, 1) == .missing(1) })
    }

    @Test("a failed install says why and can be tried again")
    func failedInstall() async {
        let (levels, log) = await makeLevels()
        await repository.failWrites()
        levels.send(.installTapped(level: 2))

        #expect(await log.contains(.showError(.installHSKFailed(FakeVocabularyRepository.failure))))
        #expect(await waitUntil { levels.state.installing.isEmpty })
        #expect(status(levels, 2) == .notAdded)
    }

    @Test("a list that cannot be read says so")
    func unreadable() async {
        await hsk.fail()
        let viewModel = HSKLevelsViewModel(
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            getWords: GetHSKWordsUseCase(hsk: hsk),
            installLevel: InstallHSKLevelUseCase(hsk: hsk, repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)

        #expect(await log.contains(.showError(.loadHSKFailed(.unexpected(model: FakeHSKRepository.failure.model)))))
        #expect(viewModel.state.levels.isEmpty)
    }
}
