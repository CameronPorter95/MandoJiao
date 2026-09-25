import Foundation
import Observation
import Testing
@testable import MandoJiao

@Suite("Speech drill microphone and lifecycle")
@MainActor
struct DrillViewModelTests {
    private let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    private let phone = WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī")
    private let green = WordPair(english: "green", hanzi: "绿", pinyin: "lǜ")

    // MARK: - Starting

    @Test("an available microphone takes the audio session and leaves typing off")
    func preparingWithAMicrophone() async {
        let drill = Drill(cards: [water, phone])
        await drill.appear()

        #expect(drill.audio.events == ["enter"])
        #expect(!drill.viewModel.state.isTyping)
        #expect(drill.viewModel.state.availabilityNotice == nil)
    }

    @Test("a refused microphone falls into typing and leaves the audio session alone")
    func preparingWithoutAMicrophone() async {
        let drill = Drill(cards: [water], availability: .needsPermission)
        await drill.appear()

        #expect(drill.viewModel.state.prefersTyping)
        #expect(drill.viewModel.state.isTyping)
        #expect(drill.viewModel.state.availabilityNotice != nil)
        #expect(drill.audio.events.isEmpty)
    }

    @Test("a request with no drillable words has no lesson and closes without asking")
    func noWords() async {
        let drill = Drill(cards: [])
        await drill.appear()
        #expect(drill.viewModel.state.lesson == nil)

        drill.viewModel.send(.closeTapped)
        #expect(await drill.effects.contains(.close))
    }

    // MARK: - Listening

    @Test("listening is hinted with the card's hanzi and pinyin")
    func hints() async {
        let drill = Drill(cards: [water], heard: ["shui"])
        await drill.appear()

        drill.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { drill.recogniser.startCount == 1 })
        #expect(drill.recogniser.lastHints == ["水", "shuǐ"])
    }

    @Test("the live transcript reaches the screen while listening")
    func liveTranscript() async {
        let drill = Drill(cards: [water], heard: ["shui"], waitForEnd: Drill.untilCancelled)
        await drill.appear()

        drill.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { drill.viewModel.state.mic == .listening })
        #expect(await waitUntil { drill.viewModel.state.partialText == "shui" })
    }

    @Test("starting a listen clears the last failure without spending a try")
    func listeningClearsAFailure() async {
        let drill = Drill(cards: [water], waitForEnd: Drill.untilCancelled)
        await drill.appear()
        drill.viewModel.send(.typedAnswerSubmitted("cha"))
        #expect(drill.viewModel.state.lesson?.phase == .wrong(heard: "cha", attemptsLeft: 2))

        drill.viewModel.send(.startListeningTapped)

        #expect(drill.viewModel.state.lesson?.phase == .idle)
        #expect(drill.viewModel.state.mic == .arming)
        #expect(drill.viewModel.state.lesson?.attemptsLeft == 2)
    }

    @Test("silence after a tap counts as an attempt")
    func silenceAfterATap() async {
        let drill = Drill(cards: [water])
        await drill.appear()

        drill.viewModel.send(.startListeningTapped)

        #expect(await waitUntil { drill.viewModel.state.lesson?.attemptsUsed == 1 })
        #expect(drill.viewModel.state.lesson?.phase == .wrong(heard: "", attemptsLeft: 2))
    }

    @Test("a correct answer carries on listening into the next word")
    func autoListenAfterCorrect() async {
        let drill = Drill(cards: [water, phone], heard: ["shui"])
        await drill.appear()

        drill.viewModel.send(.startListeningTapped)

        #expect(await waitUntil { drill.viewModel.state.lesson?.cardIndex == 1 })
        #expect(await waitUntil { drill.recogniser.startCount == 2 })
    }

    @Test("silence during a listen the drill started itself is not an attempt")
    func silenceAfterAnAutomaticListen() async {
        // The automatic listen can open before the next word has even been read.
        let drill = Drill(cards: [water, phone], heard: ["shui"])
        await drill.appear()

        drill.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { drill.recogniser.stopCount == 2 })
        #expect(await waitUntil { drill.viewModel.state.mic == .idle })

        #expect(drill.viewModel.state.lesson?.cardIndex == 1)
        #expect(drill.viewModel.state.lesson?.attemptsUsed == 0)
        #expect(drill.viewModel.state.lesson?.phase == .idle)
    }

    @Test("running out of attempts stops the microphone at the next word")
    func noAutoListenAfterExhaustion() async {
        // The answer is left on screen to be read, rather than carrying straight on.
        let drill = Drill(cards: [water, phone])
        await drill.appear()
        for _ in 0..<3 { drill.viewModel.send(.typedAnswerSubmitted("x")) }

        drill.viewModel.send(.continueTapped)
        await settle()

        #expect(drill.viewModel.state.lesson?.cardIndex == 1)
        #expect(drill.recogniser.startCount == 0)
    }

    @Test("choosing to type stops a correct answer from opening the microphone")
    func noAutoListenWhileTyping() async {
        let drill = Drill(cards: [water, phone])
        await drill.appear()
        drill.viewModel.send(.typingToggled)

        drill.viewModel.send(.typedAnswerSubmitted("shui"))

        #expect(await waitUntil { drill.viewModel.state.lesson?.cardIndex == 1 })
        await settle()
        #expect(drill.recogniser.startCount == 0)
    }

    @Test("leaving the foreground stops listening without grading anything")
    func leavingTheForeground() async {
        let drill = Drill(cards: [water], heard: ["shui"], waitForEnd: Drill.untilCancelled)
        await drill.appear()
        drill.viewModel.send(.startListeningTapped)
        #expect(await waitUntil { drill.viewModel.state.mic == .listening })

        drill.viewModel.send(.sceneLeftForeground)

        #expect(drill.viewModel.state.mic == .idle)
        #expect(await waitUntil { drill.recogniser.stopCount == 1 })
        await settle()
        #expect(drill.viewModel.state.lesson?.attemptsUsed == 0)
    }

    // MARK: - Cards

    @Test("advancing by hand cannot be doubled by the pending auto-advance")
    func manualAdvanceCancelsTheScheduledOne() async {
        let drill = Drill(cards: [water, phone, green], advanceDelay: .milliseconds(100))
        await drill.appear()
        drill.viewModel.send(.typingToggled)

        drill.viewModel.send(.typedAnswerSubmitted("shui"))
        drill.viewModel.send(.continueTapped)
        #expect(drill.viewModel.state.lesson?.cardIndex == 1)

        try? await Task.sleep(for: .milliseconds(300))
        #expect(drill.viewModel.state.lesson?.cardIndex == 1)
    }

    @Test("every verdict fires its own haptic, even two identical ones in a row")
    func haptics() async {
        let drill = Drill(cards: [water])
        await drill.appear()

        drill.viewModel.send(.typedAnswerSubmitted("x"))
        drill.viewModel.send(.typedAnswerSubmitted("x"))
        drill.viewModel.send(.typedAnswerSubmitted("shui"))

        #expect(await drill.effects.equals([.haptic(.error), .haptic(.error), .haptic(.success)]))
    }

    @Test("a drill plays no per-card tones")
    func noPerCardTones() async {
        // Settled: haptics carry the verdict. See CLAUDE.md before changing this.
        let drill = Drill(cards: [water, phone])
        await drill.appear()

        drill.viewModel.send(.typedAnswerSubmitted("x"))
        drill.viewModel.send(.typedAnswerSubmitted("shui"))
        await settle()

        #expect(!drill.audio.events.contains("match"))
        #expect(!drill.audio.events.contains("miss"))
    }

    // MARK: - Finishing

    @Test("finishing records results, then hands back the session before the fanfare")
    func finishing() async {
        let drill = Drill(cards: [water])
        await drill.appear()

        drill.viewModel.send(.typedAnswerSubmitted("shui"))

        #expect(await waitUntil { drill.audio.events == ["enter", "exit", "fanfare"] })
        #expect(await waitUntil { await drill.recorded().count == 1 })
        #expect(await drill.recorded().first?.cleanSolves == [water.id: 1])
    }

    @Test("closing after finishing does not record the results twice")
    func closingAfterFinishing() async {
        let drill = Drill(cards: [water])
        await drill.appear()
        drill.viewModel.send(.typedAnswerSubmitted("shui"))
        #expect(await waitUntil { drill.viewModel.state.lesson?.isFinished == true })

        drill.viewModel.send(.closeTapped)

        #expect(await drill.effects.contains(.close))
        await settle()
        #expect(await drill.recorded().count == 1)
    }

    @Test("practising again starts over and takes the audio session back")
    func practisingAgain() async {
        let drill = Drill(cards: [water])
        await drill.appear()
        drill.viewModel.send(.typedAnswerSubmitted("shui"))
        #expect(await waitUntil { drill.audio.events.last == "fanfare" })

        drill.viewModel.send(.practiseAgainTapped)

        #expect(drill.viewModel.state.lesson?.isFinished == false)
        #expect(drill.viewModel.state.lesson?.cleanSolvesByPairID.isEmpty == true)
        #expect(drill.audio.events.last == "enter")
    }

    // MARK: - Quitting

    @Test("closing before anything is answered needs no confirmation")
    func closingUntouched() async {
        let drill = Drill(cards: [water, phone])
        await drill.appear()

        drill.viewModel.send(.closeTapped)

        #expect(!drill.viewModel.state.isConfirmingQuit)
        #expect(await drill.effects.contains(.close))
    }

    @Test("quitting partway asks first, and a confirmed quit keeps the mistakes")
    func quittingPartway() async {
        let drill = Drill(cards: [water, phone])
        await drill.appear()
        for _ in 0..<3 { drill.viewModel.send(.typedAnswerSubmitted("x")) }

        drill.viewModel.send(.closeTapped)
        #expect(drill.viewModel.state.isConfirmingQuit)
        await settle()
        #expect(await drill.recorded().isEmpty)

        drill.viewModel.send(.quitConfirmed)
        #expect(await drill.effects.contains(.close))
        #expect(await waitUntil { await drill.recorded().first?.misses == [water.id: 1] })
    }

    @Test("a failed save is shown and logged, and the drill still closes")
    func failedSave() async {
        let drill = Drill(cards: [water, phone])
        await drill.repository.failWrites()
        await drill.appear()
        for _ in 0..<3 { drill.viewModel.send(.typedAnswerSubmitted("x")) }

        drill.viewModel.send(.closeTapped)
        drill.viewModel.send(.quitConfirmed)

        #expect(await drill.effects.contains(.close))
        #expect(await drill.effects.contains(.showError(.recordResultsFailed(FakeVocabularyRepository.failure))))
    }

    @Test("the card limit and strictness come from settings")
    func settings() async {
        let drill = Drill(cards: [water, phone, green], settings: DrillSettings(strictness: .strict, cardLimit: 2))
        await drill.appear()

        #expect(drill.viewModel.state.lesson?.plan.cardCount == 2)
        #expect(drill.viewModel.state.lesson?.strictness == .strict)
    }

    @Test("cancelling a quit keeps the drill going")
    func cancellingAQuit() async {
        let drill = Drill(cards: [water, phone])
        await drill.appear()
        for _ in 0..<3 { drill.viewModel.send(.typedAnswerSubmitted("x")) }
        drill.viewModel.send(.closeTapped)

        drill.viewModel.send(.quitCancelled)
        await settle()

        #expect(!drill.viewModel.state.isConfirmingQuit)
        #expect(!drill.effects.effects.contains(.close))
        #expect(await drill.recorded().isEmpty)
    }
}

// MARK: - Harness

@MainActor
private final class Drill {
    let viewModel: DrillViewModel
    let recogniser: FakeRecogniser
    let audio = FakeAudio()
    let effects: EffectLog<DrillEffect>
    let repository = FakeVocabularyRepository()

    /// Settles as soon as anything has been heard, and runs out otherwise.
    nonisolated static let settleOnSpeech: DrillViewModel.WaitForEnd = { transcript in
        transcript().isEmpty ? .reachedLimit : .settled
    }

    /// Keeps listening until something stops it.
    nonisolated static let untilCancelled: DrillViewModel.WaitForEnd = { _ in
        while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(5)) }
        return .reachedLimit
    }

    init(
        cards: [WordPair],
        availability: SpeechAvailability = .ready,
        heard: [String] = [],
        advanceDelay: Duration = .milliseconds(1),
        waitForEnd: @escaping DrillViewModel.WaitForEnd = settleOnSpeech,
        settings: DrillSettings = .default
    ) {
        recogniser = FakeRecogniser(preparesTo: availability, heard: heard)
        viewModel = DrillViewModel(
            request: LessonRequest(title: "t", pool: cards),
            recogniser: recogniser,
            audioSession: audio,
            sounds: audio,
            getSettings: GetDrillSettingsUseCase(repository: FixedDrillSettings(value: settings)),
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

private struct FixedDrillSettings: DrillSettingsRepository {
    let value: DrillSettings
    func settings() -> DrillSettings { value }
}
