import LibraryDomain

public struct SpeakingInput {
    public let request: LessonRequest
    /// Owned by Vocabulary, which this package cannot reach, so the app hands it in.
    public let recordResults: RecordLessonResultsUseCase
    /// Heard in place of the microphone when set.
    public let speech: ScriptedSpeech?

    public init(request: LessonRequest, recordResults: RecordLessonResultsUseCase, speech: ScriptedSpeech? = nil) {
        self.request = request
        self.recordResults = recordResults
        self.speech = speech
    }
}
