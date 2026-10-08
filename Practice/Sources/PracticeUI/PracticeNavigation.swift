/// Every way out of the package's screens, one member per screen that has one.
@MainActor
public struct PracticeNavigation {
    public var matching: MatchingNavigation
    public var speaking: SpeakingNavigation
    public var flashcards: FlashcardsNavigation
    public var mixedLesson: MixedLessonNavigation

    public init(
        matching: MatchingNavigation,
        speaking: SpeakingNavigation,
        flashcards: FlashcardsNavigation,
        mixedLesson: MixedLessonNavigation
    ) {
        self.matching = matching
        self.speaking = speaking
        self.flashcards = flashcards
        self.mixedLesson = mixedLesson
    }
}
