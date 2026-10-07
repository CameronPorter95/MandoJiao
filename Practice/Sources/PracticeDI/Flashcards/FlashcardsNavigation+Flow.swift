import PracticeUI

public extension FlashcardsNavigation {
    /// A flash card lesson presented over the app. Closing it is the presenter's dismissal
    /// (N5), so the presenter supplies it.
    static func app(dismiss: @escaping () -> Void) -> Self {
        FlashcardsNavigation(didClose: dismiss)
    }
}
