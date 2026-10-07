import PracticeUI

public extension MatchingNavigation {
    /// A matching lesson presented over the home stack. Closing it is the presenter's
    /// dismissal (N5), so the presenter supplies it.
    static func app(dismiss: @escaping () -> Void) -> Self {
        MatchingNavigation(didClose: dismiss)
    }
}
