import LibraryDomain

public struct MatchingInput {
    public let request: LessonRequest
    /// Owned by Vocabulary, which this package cannot reach, so the app hands it in.
    public let recordResults: RecordLessonResultsUseCase

    public init(request: LessonRequest, recordResults: RecordLessonResultsUseCase) {
        self.request = request
        self.recordResults = recordResults
    }
}
