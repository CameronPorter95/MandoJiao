import Foundation

/// Decides when someone has finished speaking.
///
/// The transcriber reports what it has heard so far but never says "they have stopped",
/// so the end of an utterance has to be inferred: once the live transcript stops
/// changing, the speaker has stopped. Without this a card waits out its whole time limit
/// however quickly the answer came.
@MainActor
enum Endpointing {
    enum Ending: Equatable {
        /// The transcript stopped changing, so the answer is in.
        case settled
        /// Time ran out. Either nothing was said, or it is still going and has to be cut.
        case reachedLimit
    }

    /// Long enough not to clip the gap between syllables of a two-character word, short
    /// enough that answering feels immediate.
    ///
    /// Nonisolated, along with the other two, so they can serve as default arguments:
    /// those are evaluated in the caller's context rather than this type's.
    nonisolated static let settleAfter: Duration = .milliseconds(700)

    /// A backstop for silence, or for someone who keeps talking.
    nonisolated static let hardLimit: Duration = .seconds(5)

    nonisolated static let pollInterval: Duration = .milliseconds(80)

    /// Polls rather than observing, because the transcript arrives on the recogniser's
    /// own schedule and what matters is how long it has been still, not each change.
    static func waitForEnd(
        settleAfter: Duration = settleAfter,
        hardLimit: Duration = hardLimit,
        pollInterval: Duration = pollInterval,
        transcript: () -> String
    ) async -> Ending {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: hardLimit)

        var lastText = transcript()
        var lastChange = clock.now

        while clock.now < deadline {
            if Task.isCancelled { return .reachedLimit }
            try? await Task.sleep(for: pollInterval)

            let current = transcript()
            if current != lastText {
                lastText = current
                lastChange = clock.now
            } else if !current.isEmpty, clock.now - lastChange >= settleAfter {
                return .settled
            }
        }

        return .reachedLimit
    }
}
