/// Every way out of the package's screens, one member per screen that has one.
///
/// The library and the word editor have none: the editor is a sheet its presenter
/// dismisses, and the library is left with the back button.
@MainActor
public struct VocabularyNavigation {
    public var home: HomeNavigation
    public var deckDetail: DeckDetailNavigation
    public var library: LibraryNavigation

    public init(home: HomeNavigation, deckDetail: DeckDetailNavigation, library: LibraryNavigation) {
        self.home = home
        self.deckDetail = deckDetail
        self.library = library
    }
}
