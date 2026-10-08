import PracticeData
import PracticeDomain

/// Answers heard in place of the microphone's: each listen hears the next one queued. For
/// driving a speaking lesson headlessly, or in a debug build launched with -scripted-speech.
@MainActor
public final class ScriptedSpeech {
    let recogniser = ScriptedRecogniser()

    public init() {}

    public func enqueue(_ answer: String) {
        recogniser.enqueue(SpeechOutcome(best: answer))
    }
}
