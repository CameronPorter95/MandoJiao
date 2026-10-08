import CoreUI
import Foundation
import LibraryDomain

extension LibraryViewModel {
    /// `root` and `page` build what the sidebar selects and what is pushed over it, as the Route's do.
    public func driver(
        navigation: LibraryTabNavigation,
        root: @escaping (LibrarySelection, LibraryPageContext) -> ScreenDriver,
        page: @escaping (LibraryPage, LibraryPageContext) -> ScreenDriver
    ) -> ScreenDriver {
        let children = ChildDrivers<LibraryChild>()
        return ScreenDriver(
            name: "library",
            actions: LibraryAction.names,
            state: { self.state },
            summary: \.summary,
            send: send,
            effects: effects,
            follow: navigation.follow,
            front: {
                let stack = (self.state.selection.map { [LibraryChild.root($0)] } ?? [])
                    + self.state.path.enumerated().map { LibraryChild.page($0.offset, $0.element) }
                return children.front(of: stack) { child in
                    switch child {
                    case .root(let selection): root(selection, self.pageContext)
                    case .page(_, let pushed): page(pushed, self.pageContext)
                    }
                }
            },
            back: {
                guard !self.state.path.isEmpty else { return false }
                self.send(.pathChanged(Array(self.state.path.dropLast())))
                return true
            },
            relay: children.relay
        )
    }
}

/// The same page can be pushed twice, so a page is told apart by its place in the stack too.
private enum LibraryChild: Hashable {
    case root(LibrarySelection)
    case page(Int, LibraryPage)
}

extension LibraryAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "selected", "opened", "pathChanged", "folderExpanded",
        "folderSectionToggled", "deckSortChanged", "wordSortChanged", "hskLevelsTapped",
        "hskLevelsDismissed", "searchPresentedChanged", "searchChanged", "newWordTapped",
        "editorDismissed", "editTapped", "folderMoved", "newFolderTapped", "renameFolderTapped",
        "nameChanged", "namingConfirmed", "namingCancelled", "practiseFolderTapped",
        "deleteFolderTapped", "deleteFolderConfirmed", "deleteFolderCancelled",
    ]
}

extension LibraryState {
    var summary: String {
        let folders = vocabulary.folders.filter { $0.parentID == nil }
            .map { "\($0.displayName) \($0.id.uuidString.prefix(8))" }
        var parts = ["library", "folders: \(folders.joined(separator: ", "))"]
        if case .folder(let id) = selection, let folder = vocabulary.folder(id: id) {
            parts.append("selected: \(folder.displayName)")
        }
        if isSearching { parts.append("searching: \(searchText)") }
        if editor != nil { parts.append("editing a word") }
        if isShowingHSKLevels { parts.append("HSK levels open") }
        return parts.joined(separator: "  ")
    }
}
