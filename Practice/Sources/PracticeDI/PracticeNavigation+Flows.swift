import PracticeUI

public extension PracticeNavigation {
    /// Every lesson presented over the app, composed from each screen's own constructor.
    /// Closing any of them is the presenter's dismissal (N5).
    static func app(dismiss: @escaping () -> Void) -> Self {
        PracticeNavigation(
            matching: .app(dismiss: dismiss),
            speaking: .app(dismiss: dismiss),
            flashcards: .app(dismiss: dismiss),
            mixedLesson: .app(dismiss: dismiss)
        )
    }
}
