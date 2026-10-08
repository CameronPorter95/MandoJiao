import CoreDomain
import CoreTestSupport
import Foundation
import Testing
@testable import PracticeDomain
@testable import PracticeUI
import LibraryDomain
import LibraryTestSupport

@Suite("Matching lesson screen")
@MainActor
struct MatchingViewModelTests {
    private let pairs = [
        WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
        WordPair(english: "tea", hanzi: "茶", pinyin: "chá"),
        WordPair(english: "book", hanzi: "书", pinyin: "shū"),
        WordPair(english: "car", hanzi: "车", pinyin: "chē"),
        WordPair(english: "big", hanzi: "大", pinyin: "dà"),
    ]

    // MARK: - Starting

    @Test("appearing readies the sounds and builds the lesson from the settings")
    func appearing() {
        let harness = Harness(pool: pairs, settings: MatchingSettings(showsPinyin: true, rounds: 3))
        harness.viewModel.send(.appeared)

        #expect(harness.sounds.events == ["prepare"])
        #expect(harness.viewModel.state.lesson?.plan.exerciseCount == 3)
        #expect(harness.viewModel.state.showsPinyin)
    }

    @Test("too few words means no lesson, and closing needs no confirmation")
    func tooFewWords() async {
        let harness = Harness(pool: Array(pairs.prefix(4)))
        harness.viewModel.send(.appeared)
        #expect(harness.viewModel.state.lesson == nil)

        harness.viewModel.send(.closeTapped)
        #expect(await harness.effects.contains(.close))
    }

    // MARK: - Tapping

    @Test("each tap gets its sound and its haptic")
    func tapFeedback() async {
        let harness = Harness(pool: pairs)
        harness.viewModel.send(.appeared)

        harness.tap(pairs[0], .english)
        harness.tap(pairs[1], .hanzi)
        harness.match(pairs[0])

        #expect(harness.sounds.events == ["prepare", "miss", "match 0/5"])
        #expect(await harness.effects.equals([
            .haptic(.selection), .haptic(.miss), .haptic(.selection), .haptic(.match),
        ]))
    }

    @Test("clearing a board moves to the next after a pause, ignoring taps meanwhile")
    func clearingABoard() async {
        // Long enough that a busy simulator cannot run it out before the tap below: at 100ms,
        // waiting for the success haptic alone took longer in the full suite.
        let harness = Harness(pool: pairs, settings: MatchingSettings(showsPinyin: false, rounds: 2), advanceDelay: .milliseconds(600))
        harness.viewModel.send(.appeared)

        pairs.forEach { harness.match($0) }
        #expect(await harness.effects.contains(.haptic(.success)))
        harness.tap(pairs[0], .english)
        #expect(harness.viewModel.state.lesson?.exerciseIndex == 0)

        #expect(await waitUntil { harness.viewModel.state.lesson?.exerciseIndex == 1 })
    }

    @Test("pinyin visibility is saved when toggled")
    func pinyinToggle() {
        let harness = Harness(pool: pairs)
        harness.viewModel.send(.appeared)
        harness.viewModel.send(.pinyinToggled)

        #expect(harness.viewModel.state.showsPinyin)
        #expect(harness.settings.saved == [true])
    }

    // MARK: - Finishing

    @Test("finishing plays the fanfare and records the results once")
    func finishing() async {
        let harness = Harness(pool: pairs, settings: MatchingSettings(showsPinyin: false, rounds: 1))
        harness.viewModel.send(.appeared)
        pairs.forEach { harness.match($0) }

        #expect(await waitUntil { harness.viewModel.state.lesson?.isFinished == true })
        #expect(harness.sounds.events.last == "fanfare")
        #expect(await waitUntil { await harness.repository.recordedResults.count == 1 })
        #expect(await harness.repository.recordedResults.first?.cleanSolves.count == 5)
        // So the deck is marked practised, for home to carry on with.
        #expect(await harness.repository.recordedResults.first?.source == .deck(testDeckID))

        harness.viewModel.send(.closeTapped)
        #expect(await harness.effects.contains(.close))
        await settle()
        #expect(await harness.repository.recordedResults.count == 1)
    }

    @Test("practising again starts a fresh lesson")
    func practisingAgain() async {
        let harness = Harness(pool: pairs, settings: MatchingSettings(showsPinyin: false, rounds: 1))
        harness.viewModel.send(.appeared)
        pairs.forEach { harness.match($0) }
        #expect(await waitUntil { harness.viewModel.state.lesson?.isFinished == true })

        harness.viewModel.send(.practiseAgainTapped)

        #expect(harness.viewModel.state.lesson?.isFinished == false)
        #expect(harness.viewModel.state.lesson?.cleanSolvesByPairID.isEmpty == true)
    }

    // MARK: - Quitting

    @Test("quitting partway asks first, and a confirmed quit keeps the mistakes")
    func quittingPartway() async {
        let harness = Harness(pool: pairs)
        harness.viewModel.send(.appeared)
        harness.tap(pairs[0], .english)
        harness.tap(pairs[1], .hanzi)
        harness.match(pairs[2])

        harness.viewModel.send(.closeTapped)
        #expect(harness.viewModel.state.isConfirmingQuit)

        harness.viewModel.send(.quitConfirmed)
        #expect(await harness.effects.contains(.close))
        #expect(await waitUntil { await harness.repository.recordedResults.first?.misses == [pairs[0].id: 1, pairs[1].id: 1] })
    }

    @Test("cancelling a quit keeps the lesson going and records nothing")
    func cancellingAQuit() async {
        let harness = Harness(pool: pairs)
        harness.viewModel.send(.appeared)
        harness.match(pairs[0])
        harness.viewModel.send(.closeTapped)

        harness.viewModel.send(.quitCancelled)
        await settle()

        #expect(!harness.viewModel.state.isConfirmingQuit)
        #expect(!harness.effects.effects.contains(.close))
        #expect(await harness.repository.recordedResults.isEmpty)
    }

    @Test("a failed save is shown and logged, and the lesson still closes")
    func failedSave() async {
        let harness = Harness(pool: pairs)
        await harness.repository.failWrites()
        harness.viewModel.send(.appeared)
        harness.match(pairs[0])

        harness.viewModel.send(.closeTapped)
        harness.viewModel.send(.quitConfirmed)

        #expect(await harness.effects.contains(.close))
        #expect(await harness.effects.contains(.showError(.recordResultsFailed(FakeVocabularyRepository.failure))))
    }
}

// MARK: - Harness

@MainActor
private final class Harness {
    let viewModel: MatchingViewModel
    let sounds = FakeSounds()
    let settings: FakeMatchingSettings
    let repository = FakeVocabularyRepository()
    let effects: EffectLog<MatchingEffect>

    init(
        pool: [WordPair],
        settings: MatchingSettings = MatchingSettings(showsPinyin: false, rounds: 2),
        advanceDelay: Duration = .milliseconds(1)
    ) {
        self.settings = FakeMatchingSettings(settings)
        viewModel = MatchingViewModel(
            request: LessonRequest(title: "t", pool: pool, source: .deck(testDeckID)),
            sounds: sounds,
            getSettings: GetMatchingSettingsUseCase(repository: self.settings),
            setShowsPinyin: SetShowsPinyinUseCase(repository: self.settings),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            advanceDelay: advanceDelay
        )
        effects = EffectLog(viewModel.effects())
    }

    func tap(_ pair: WordPair, _ side: TileSide) {
        guard let lesson = viewModel.state.lesson else { return }
        viewModel.send(.tileTapped(lesson.tile(pair, side)))
    }

    func match(_ pair: WordPair) {
        tap(pair, .english)
        tap(pair, .hanzi)
    }
}

@MainActor
private final class FakeSounds: MatchSoundPlaying {
    private(set) var events: [String] = []

    func prepare() { events.append("prepare") }
    func playMatch(step: Int, of total: Int) { events.append("match \(step)/\(total)") }
    func playMiss() { events.append("miss") }
    func playLessonComplete() { events.append("fanfare") }
}

private final class FakeMatchingSettings: MatchingSettingsRepository, @unchecked Sendable {
    private let value: MatchingSettings
    private(set) var saved: [Bool] = []

    init(_ value: MatchingSettings) {
        self.value = value
    }

    func settings() -> MatchingSettings { value }
    func setShowsPinyin(_ showsPinyin: Bool) { saved.append(showsPinyin) }
    func setRounds(_ rounds: Int) {}
}

private let testDeckID = UUID()
