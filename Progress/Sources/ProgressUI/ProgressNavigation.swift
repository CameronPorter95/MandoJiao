/// Every way out of the package's screens, one member per screen that has one. Only Home
/// for now; streaks, goals and rewards will join it.
@MainActor
public struct ProgressNavigation {
    public var home: HomeNavigation

    public init(home: HomeNavigation) {
        self.home = home
    }
}
