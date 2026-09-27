import Foundation
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

@Suite("Home")
@MainActor
struct HomeViewModelTests {
    private let repository = FakeVocabularyRepository(Fixtures.vocabulary)
    private let rounds = Box(10)

    private func makeHome() async -> (HomeViewModel, EffectLog<HomeEffect>) {
        let viewModel = HomeViewModel(
            minimumMatchingWords: 5,
            quickPracticeRounds: { rounds.value },
            observeVocabulary: ObserveVocabularyUseCase(repository: repository),
            clearMistakes: ClearMistakesUseCase(repository: repository)
        )
        let log = EffectLog(viewModel.effects())
        viewModel.send(.appeared)
        _ = await waitUntil { viewModel.state.vocabulary == Fixtures.vocabulary }
        return (viewModel, log)
    }

    @Test("appearing shows the library")
    func loading() async {
        let (home, _) = await makeHome()
        #expect(home.state.usableWordCount == 5)
        #expect(home.state.canStartQuickPractice)
        #expect(home.state.mistakeWords.map(\.english) == ["mobile phone", "book", "tea"])
    }

    @Test("quick practice asks for a matching lesson over every usable word")
    func quickPractice() async {
        let (home, log) = await makeHome()
        home.send(.quickPracticeTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestMatching(let request) = log.effects.first else {
            Issue.record("expected a matching request")
            return
        }
        #expect(request.title == "All words")
        #expect(request.pool.count == 5)
    }

    @Test("practising mistakes asks for a speaking lesson, worst first, with no floor")
    func practiseMistakes() async {
        let (home, log) = await makeHome()
        home.send(.practiseMistakesTapped)

        #expect(await waitUntil { log.effects.count == 1 })
        guard case .requestSpeaking(let request) = log.effects.first else {
            Issue.record("expected a drill request")
            return
        }
        #expect(request.pool.map(\.english) == ["mobile phone", "book", "tea"])
    }

    @Test("clearing mistakes asks first")
    func clearingMistakes() async {
        let (home, _) = await makeHome()
        home.send(.clearMistakesTapped)
        #expect(home.state.isConfirmingClear)
        home.send(.clearMistakesCancelled)
        await settle()
        #expect(await repository.writes.isEmpty)

        home.send(.clearMistakesTapped)
        home.send(.clearMistakesConfirmed)
        #expect(await waitUntil { home.state.mistakeWords.isEmpty })
    }

    @Test("the quick practice round count is asked again on every return")
    func roundsReread() async {
        let (home, _) = await makeHome()
        #expect(home.state.quickPracticeRounds == 10)

        home.send(.disappeared)
        rounds.value = 15
        home.send(.appeared)

        #expect(home.state.quickPracticeRounds == 15)
    }

    @Test("changes made while away show on return")
    func reappearing() async {
        let (home, _) = await makeHome()
        home.send(.disappeared)
        await repository.replace(.empty)
        await settle()
        #expect(home.state.vocabulary == Fixtures.vocabulary)

        home.send(.appeared)
        #expect(await waitUntil { home.state.vocabulary == .empty })
    }

}

@MainActor
private final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}
