import CoreUI
import Foundation
import LibraryDomain

extension LibraryViewModel {
    /// `root` and `page` build what the sidebar selects and what is pushed over it, as the Route's
    /// do. Without them it has nothing in front of it, as in the app, where the views hold the stack.
    public func driver(
        navigation: LibraryTabNavigation,
        root: ((LibrarySelection, LibraryPageContext) -> ScreenDriver)? = nil,
        page: ((LibraryPage, LibraryPageContext) -> ScreenDriver)? = nil
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
                guard let root, let page else { return nil }
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
                if !self.state.path.isEmpty {
                    self.send(.pathChanged(Array(self.state.path.dropLast())))
                } else if self.state.selection != nil {
                    // Back to the sidebar, as on iPhone.
                    self.send(.selected(nil))
                } else {
                    return false
                }
                return true
            },
            relay: children.relay,
            open: { kind, query in try self.open(kind, query) }
        )
    }

    /// A deck is pushed, a top-level folder selected in the sidebar, and a folder inside another
    /// pushed. Found by name, ignoring case, then by built-in key, then by the start of its id.
    private func open(_ kind: String, _ query: String) throws {
        let vocabulary = state.vocabulary
        switch kind {
        case "deck":
            guard let deck = Self.find(query, in: vocabulary.decks, name: \.name, key: \.builtInKey) else {
                throw ScreenDriverError.notFound(kind, query)
            }
            send(.opened(.deck(deck.id)))
        case "folder":
            guard let folder = Self.find(query, in: vocabulary.folders, name: \.name, key: \.builtInKey) else {
                throw ScreenDriverError.notFound(kind, query)
            }
            send(folder.parentID == nil ? .selected(.folder(folder.id)) : .opened(.folder(folder.id)))
        default:
            throw ScreenDriverError.cannotOpen(kind)
        }
    }

    private static func find<Item: Identifiable>(
        _ query: String, in items: [Item], name: KeyPath<Item, String>, key: KeyPath<Item, String?>
    ) -> Item? where Item.ID == UUID {
        let lowered = query.lowercased()
        return items.first { $0[keyPath: name].lowercased() == lowered }
            ?? items.first { $0[keyPath: key] == query }
            ?? items.first { $0.id.uuidString.lowercased().hasPrefix(lowered) }
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
