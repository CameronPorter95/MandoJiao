import SpeakingUI

public extension SpeakingNavigation {
    /// A speaking lesson presented over the home stack. Closing it is the presenter's
    /// dismissal (N5), so the presenter supplies it.
    static func app(dismiss: @escaping () -> Void) -> Self {
        SpeakingNavigation(didClose: dismiss)
    }
}
