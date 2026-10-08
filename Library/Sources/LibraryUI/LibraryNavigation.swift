/// Every way out of the package's screens, one member per screen that has one.
///
/// The word editor has none: it is a sheet its presenter dismisses. A folder's navigation
/// is made by the library tab, whose stack it is pushed onto.
@MainActor
public struct LibraryNavigation {
    public var deckDetail: DeckDetailNavigation
    public var libraryTab: LibraryTabNavigation

    public init(deckDetail: DeckDetailNavigation, libraryTab: LibraryTabNavigation) {
        self.deckDetail = deckDetail
        self.libraryTab = libraryTab
    }
}
