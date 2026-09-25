import Foundation
import Observation
import Testing
@testable import MandoJiao

@Suite("Speaking lesson microphone and lifecycle")
@MainActor
struct SpeakingViewModelTests {
    private let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    private let phone = WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī")
    private let green = WordPair(english: "green", hanzi: "绿", pinyin: "lǜ")

    // MARK: - Starting

    @Test("an available microphone takes the audio session and leaves typing off")
    func preparingWithAMicrophone() async {
        let harness = Harness(cards: [water, phone])
        await harness.appear()

        #expect(harness.audio.events == ["enter"])
        #expect(!harness.viewModel.state.isTyping)
        #expect(harness.viewModel.state.availabilityNotice == nil)
    }

    @Test("a refused microphone falls into typing and leaves the audio session alone")
    func preparingWithoutAMicrophone() async {
        let harness = Harness(cards: [water], availability: .needsPermission)
        await harness.appear()

        #expect(harness.viewModel.state.prefersTyping)
        #expect(harness.viewModel.state.isTyping)
        #expect(harness.viewModel.state.availabilityNotice != nil)
        #expect(harness.audio.events.isEmpty)
    }

    @Test("a request with no drillable words has no lesson and closes without asking")
    func noWords() async {
        let harness = Harness(cards: [])
        await harness.appear()
        #expect(harness.viewModel.state.lesson == nil)

        harness.viewModel.send(.closeTapped)
        #expect(await harness.effects.contains(.close))
    }

    // MARK: - Listening

    @Test("listening is hinted with the card's hanzi and pinyin")
    func hints() async {
        let harness = Harness(cards: [water], heard: ["shui"])
        await harness.appear()

        harness.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { harness.recogniser.startCount == 1 })
        #expect(harness.recogniser.lastHints == ["水", "shuǐ"])
    }

    @Test("the live transcript reaches the screen while listening")
    func liveTranscript() async {
        let harness = Harness(cards: [water], heard: ["shui"], waitForEnd: Harness.untilCancelled)
        await harness.appear()

        harness.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { harness.viewModel.state.mic == .listening })
        #expect(await waitUntil { harness.viewModel.state.partialText == "shui" })
    }

    @Test("starting a listen clears the last failure without spending a try")
    func listeningClearsAFailure() async {
        let harness = Harness(cards: [water], waitForEnd: Harness.untilCancelled)
        await harness.appear()
        harness.viewModel.send(.typedAnswerSubmitted("cha"))
        #expect(harness.viewModel.state.lesson?.phase == .wrong(heard: "cha", attemptsLeft: 2))

        harness.viewModel.send(.startListeningTapped)

        #expect(harness.viewModel.state.lesson?.phase == .idle)
        #expect(harness.viewModel.state.mic == .arming)
        #expect(harness.viewModel.state.lesson?.attemptsLeft == 2)
    }

    @Test("silence after a tap counts as an attempt")
    func silenceAfterATap() async {
        let harness = Harness(cards: [water])
        await harness.appear()

        harness.viewModel.send(.startListeningTapped)

        #expect(await waitUntil { harness.viewModel.state.lesson?.attemptsUsed == 1 })
        #expect(harness.viewModel.state.lesson?.phase == .wrong(heard: "", attemptsLeft: 2))
    }

    @Test("a correct answer carries on listening into the next word")
    func autoListenAfterCorrect() async {
        let harness = Harness(cards: [water, phone], heard: ["shui"])
        await harness.appear()

        harness.viewModel.send(.startListeningTapped)

        #expect(await waitUntil { harness.viewModel.state.lesson?.cardIndex == 1 })
        #expect(await waitUntil { harness.recogniser.startCount == 2 })
    }

    @Test("silence during a listen the speaking lesson started itself is not an attempt")
    func silenceAfterAnAutomaticListen() async {
        // The automatic listen can open before the next word has even been read.
        let harness = Harness(cards: [water, phone], heard: ["shui"])
        await harness.appear()

        harness.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { harness.recogniser.stopCount == 2 })
        #expect(await waitUntil { harness.viewModel.state.mic == .idle })

        #expect(harness.viewModel.state.lesson?.cardIndex == 1)
        #expect(harness.viewModel.state.lesson?.attemptsUsed == 0)
        #expect(harness.viewModel.state.lesson?.phase == .idle)
    }

    @Test("running out of attempts stops the microphone at the next word")
    func noAutoListenAfterExhaustion() async {
        // The answer is left on screen to be read, rather than carrying straight on.
        let harness = Harness(cards: [water, phone])
        await harness.appear()
        for _ in 0..<3 { harness.viewModel.send(.typedAnswerSubmitted("x")) }

        harness.viewModel.send(.continueTapped)
        await settle()

        #expect(harness.viewModel.state.lesson?.cardIndex == 1)
        #expect(harness.recogniser.startCount == 0)
    }

    @Test("choosing to type stops a correct answer from opening the microphone")
    func noAutoListenWhileTyping() async {
        let harness = Harness(cards: [water, phone])
        await harness.appear()
        harness.viewModel.send(.typingToggled)

        harness.viewModel.send(.typedAnswerSubmitted("shui"))

        #expect(await waitUntil { harness.viewModel.state.lesson?.cardIndex == 1 })
        await settle()
        #expect(harness.recogniser.startCount == 0)
    }

    @Test("leaving the foreground stops listening without grading anything")
    func leavingTheForeground() async {
        let harness = Harness(cards: [water], heard: ["shui"], waitForEnd: Harness.untilCancelled)
        await harness.appear()
        harness.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { harness.viewModel.state.mic == .listening })

        harness.viewModel.send(.sceneLeftForeground)

        #expect(harness.viewModel.state.mic == .idle)
        #expect(await waitUntil { harness.recogniser.stopCount == 1 })
        await settle()
        #expect(harness.viewModel.state.lesson?.attemptsUsed == 0)
    }

    // MARK: - Cards

    @Test("advancing by hand cannot be doubled by the pending auto-advance")
    func manualAdvanceCancelsTheScheduledOne() async {
        let harness = Harness(cards: [water, phone, green], advanceDelay: .milliseconds(100))
        await harness.appear()
        harness.viewModel.send(.typingToggled)

        harness.viewModel.send(.typedAnswerSubmitted("shui"))
        harness.viewModel.send(.continueTapped)
        #expect(harness.viewModel.state.lesson?.cardIndex == 1)

        try? await Task.sleep(for: .milliseconds(300))
        #expect(harness.viewModel.state.lesson?.cardIndex == 1)
    }

    @Test("every verdict fires its own haptic, even two identical ones in a row")
    func haptics() async {
        let harness = Harness(cards: [water])
        await harness.appear()

        harness.viewModel.send(.typedAnswerSubmitted("x"))
        harness.viewModel.send(.typedAnswerSubmitted("x"))
        harness.viewModel.send(.typedAnswerSubmitted("shui"))

        #expect(await harness.effects.equals([.haptic(.error), .haptic(.error), .haptic(.success)]))
    }

    @Test("a speaking lesson plays no per-card tones")
    func noPerCardTones() async {
        // Settled: haptics carry the verdict. See CLAUDE.md before changing this.
        let harness = Harness(cards: [water, phone])
        await harness.appear()

        harness.viewModel.send(.typedAnswerSubmitted("x"))
        harness.viewModel.send(.typedAnswerSubmitted("shui"))
        await settle()

        #expect(!harness.audio.events.contains("match"))
        #expect(!harness.audio.events.contains("miss"))
    }

    // MARK: - Finishing

    @Test("finishing records results, then hands back the session before the fanfare")
    func finishing() async {
        let harness = Harness(cards: [water])
        await harness.appear()

        harness.viewModel.send(.typedAnswerSubmitted("shui"))

        #expect(await waitUntil { harness.audio.events == ["enter", "exit", "fanfare"] })
        #expect(await waitUntil { await harness.recorded().count == 1 })
        #expect(await harness.recorded().first?.cleanSolves == [water.id: 1])
    }

    @Test("closing after finishing does not record the results twice")
    func closingAfterFinishing() async {
        let harness = Harness(cards: [water])
        await harness.appear()
        harness.viewModel.send(.typedAnswerSubmitted("shui"))
        #expect(await waitUntil { harness.viewModel.state.lesson?.isFinished == true })

        harness.viewModel.send(.closeTapped)

        #expect(await harness.effects.contains(.close))
        await settle()
        #expect(await harness.recorded().count == 1)
    }

    @Test("practising again starts over and takes the audio session back")
    func practisingAgain() async {
        let harness = Harness(cards: [water])
        await harness.appear()
        harness.viewModel.send(.typedAnswerSubmitted("shui"))
        #expect(await waitUntil { harness.audio.events.last == "fanfare" })

        harness.viewModel.send(.practiseAgainTapped)

        #expect(harness.viewModel.state.lesson?.isFinished == false)
        #expect(harness.viewModel.state.lesson?.cleanSolvesByPairID.isEmpty == true)
        #expect(harness.audio.events.last == "enter")
    }

    // MARK: - Quitting

    @Test("closing before anything is answered needs no confirmation")
    func closingUntouched() async {
        let harness = Harness(cards: [water, phone])
        await harness.appear()

        harness.viewModel.send(.closeTapped)

        #expect(!harness.viewModel.state.isConfirmingQuit)
        #expect(await harness.effects.contains(.close))
    }

    @Test("quitting partway asks first, and a confirmed quit keeps the mistakes")
    func quittingPartway() async {
        let harness = Harness(cards: [water, phone])
        await harness.appear()
        for _ in 0..<3 { harness.viewModel.send(.typedAnswerSubmitted("x")) }

        harness.viewModel.send(.closeTapped)
        #expect(harness.viewModel.state.isConfirmingQuit)
        await settle()
        #expect(await harness.recorded().isEmpty)

        harness.viewModel.send(.quitConfirmed)
        #expect(await harness.effects.contains(.close))
        #expect(await waitUntil { await harness.recorded().first?.misses == [water.id: 1] })
    }

    @Test("a failed save is shown and logged, and the speaking lesson still closes")
    func failedSave() async {
        let harness = Harness(cards: [water, phone])
        await harness.repository.failWrites()
        await harness.appear()
        for _ in 0..<3 { harness.viewModel.send(.typedAnswerSubmitted("x")) }

        harness.viewModel.send(.closeTapped)
        harness.viewModel.send(.quitConfirmed)

        #expect(await harness.effects.contains(.close))
        #expect(await harness.effects.contains(.showError(.recordResultsFailed(FakeVocabularyRepository.failure))))
    }

    @Test("the card limit and strictness come from settings")
    func settings() async {
        let harness = Harness(cards: [water, phone, green], settings: SpeakingSettings(strictness: .strict, cardLimit: 2))
        await harness.appear()

        #expect(harness.viewModel.state.lesson?.plan.cardCount == 2)
        #expect(harness.viewModel.state.lesson?.strictness == .strict)
    }

    @Test("cancelling a quit keeps the speaking lesson going")
    func cancellingAQuit() async {
        let harness = Harness(cards: [water, phone])
        await harness.appear()
        for _ in 0..<3 { harness.viewModel.send(.typedAnswerSubmitted("x")) }
        harness.viewModel.send(.closeTapped)

        harness.viewModel.send(.quitCancelled)
        await settle()

        #expect(!harness.viewModel.state.isConfirmingQuit)
        #expect(!harness.effects.effects.contains(.close))
        #expect(await harness.recorded().isEmpty)
    }
}

// MARK: - Harness

@MainActor
private final class Harness {
    let viewModel: SpeakingViewModel
    let recogniser: FakeRecogniser
    let audio = FakeAudio()
    let effects: EffectLog<SpeakingEffect>
    let repository = FakeVocabularyRepository()

    /// Settles as soon as anything has been heard, and runs out otherwise.
    nonisolated static let settleOnSpeech: SpeakingViewModel.WaitForEnd = { transcript in
        transcript().isEmpty ? .reachedLimit : .settled
    }

    /// Keeps listening until something stops it.
    nonisolated static let untilCancelled: SpeakingViewModel.WaitForEnd = { _ in
        while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(5)) }
        return .reachedLimit
    }

    init(
        cards: [WordPair],
        availability: SpeechAvailability = .ready,
        heard: [String] = [],
        advanceDelay: Duration = .milliseconds(1),
        waitForEnd: @escaping SpeakingViewModel.WaitForEnd = settleOnSpeech,
        settings: SpeakingSettings = .default
    ) {
        recogniser = FakeRecogniser(preparesTo: availability, heard: heard)
        viewModel = SpeakingViewModel(
            request: LessonRequest(title: "t", pool: cards),
            recogniser: recogniser,
            audioSession: audio,
            sounds: audio,
            getSettings: GetSpeakingSettingsUseCase(repository: FixedSpeakingSettings(value: settings)),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            advanceDelay: advanceDelay,
            waitForEnd: waitForEnd
        )
        effects = EffectLog(viewModel.effects())
    }

    func recorded() async -> [LessonResults] {
        await repository.recordedResults
    }

    func appear() async {
        viewModel.send(.appeared)
        let expected = recogniser.preparesTo
        _ = await waitUntil {
            self.viewModel.state.availability == expected
                && (expected.canListen ? self.audio.events.contains("enter") : self.viewModel.state.prefersTyping)
        }
    }
}

@MainActor
@Observable
private final class FakeRecogniser: SpeechRecognising {
    var availability: SpeechAvailability = .notPrepared
    var partialText = ""

    let preparesTo: SpeechAvailability
    private var heard: [String]
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var lastHints: [String] = []

    init(preparesTo: SpeechAvailability, heard: [String]) {
        self.preparesTo = preparesTo
        self.heard = heard
    }

    func prepare() async -> SpeechAvailability {
        availability = preparesTo
        return availability
    }

    /// Hears the next scripted answer as soon as listening starts, or nothing when the
    /// script has run out.
    func start(hints: [String]) async throws {
        startCount += 1
        lastHints = hints
        partialText = heard.first ?? ""
    }

    func stop() async -> SpeechOutcome {
        stopCount += 1
        guard !heard.isEmpty else { return .empty }
        return SpeechOutcome(best: heard.removeFirst())
    }

    func cancel() {
        partialText = ""
    }
}

@MainActor
private final class FakeAudio: AudioSessionSwitching, MatchSoundPlaying {
    private(set) var events: [String] = []

    func enterRecordingMode() { events.append("enter") }
    func exitRecordingMode() async { events.append("exit") }
    func playMatch(step: Int, of total: Int) { events.append("match") }
    func playMiss() { events.append("miss") }
    func playLessonComplete() { events.append("fanfare") }
}

private struct FixedSpeakingSettings: SpeakingSettingsRepository {
    let value: SpeakingSettings
    func settings() -> SpeakingSettings { value }
}
