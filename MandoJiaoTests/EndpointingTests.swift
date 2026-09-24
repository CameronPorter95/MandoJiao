import Testing
@testable import MandoJiao

@Suite("Deciding when speaking has stopped")
@MainActor
struct EndpointingTests {
    // Short enough to keep the suite quick, same shape as the real values.
    private let settle: Duration = .milliseconds(150)
    private let limit: Duration = .seconds(2)
    private let poll: Duration = .milliseconds(20)

    @Test("a transcript that stops changing ends the utterance well before the limit")
    func settlesEarly() async {
        var text = ""
        let clock = ContinuousClock()
        let started = clock.now

        // Arrives quickly, then holds still, which is what a finished answer looks like.
        let typing = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            text = "完"
            try? await Task.sleep(for: .milliseconds(60))
            text = "完成"
        }

        let ending = await Endpointing.waitForEnd(
            settleAfter: settle,
            hardLimit: limit,
            pollInterval: poll
        ) { text }
        typing.cancel()

        #expect(ending == .settled)
        #expect(clock.now - started < limit, "should not have waited out the hard limit")
    }

    @Test("silence runs to the limit rather than settling on nothing")
    func silenceReachesTheLimit() async {
        // An empty transcript never counts as settled: there is nothing to submit yet,
        // and someone who has not started talking should not be cut off immediately.
        let ending = await Endpointing.waitForEnd(
            settleAfter: settle,
            hardLimit: .milliseconds(400),
            pollInterval: poll
        ) { "" }

        #expect(ending == .reachedLimit)
    }

    @Test("someone still talking is cut off at the limit, not before")
    func keepsGoingUntilTheLimit() async {
        var count = 0
        let ending = await Endpointing.waitForEnd(
            settleAfter: settle,
            hardLimit: .milliseconds(500),
            pollInterval: poll
        ) {
            count += 1
            return String(repeating: "还", count: count)
        }

        #expect(ending == .reachedLimit)
    }

    @Test("a pause mid-answer does not end it early if speech resumes")
    func resumingResetsTheTimer() async {
        var text = "完"
        let resume = Task { @MainActor in
            // Longer than a poll, shorter than the settle window.
            try? await Task.sleep(for: .milliseconds(100))
            text = "完成"
        }

        let ending = await Endpointing.waitForEnd(
            settleAfter: settle,
            hardLimit: limit,
            pollInterval: poll
        ) { text }
        resume.cancel()

        #expect(ending == .settled)
        #expect(text == "完成", "the later syllable should have been picked up")
    }
}
