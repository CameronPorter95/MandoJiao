import CoreUI
import Foundation

extension FolderDetailViewModel {
    /// `results` builds the words its search finds, as the Route's does. Without it nothing is
    /// in front of it, as in the app.
    public func driver(
        navigation: FolderDetailNavigation,
        results: ((_ searchText: String) -> ScreenDriver)? = nil
    ) -> ScreenDriver {
        let children = ChildDrivers<String>()
        let search = SearchHandOn()
        return ScreenDriver(
            name: "folder",
            actions: FolderDetailAction.names,
            state: { self.state },
            summary: { state in
                let decks = state.decks.map { "\($0.name) \($0.id.uuidString.prefix(8))" }
                let folders = state.subfolders.map { "\($0.folder.name) \($0.id.uuidString.prefix(8))" }
                return [
                    "folder", state.title, "lesson words: \(state.wordCount)",
                    "decks: \(decks.joined(separator: ", "))",
                    "folders: \(folders.isEmpty ? "none" : folders.joined(separator: ", "))",
                ].joined(separator: "  ")
            },
            send: send,
            effects: effects,
            follow: navigation.follow,
            front: {
                guard let results else { return nil }
                let front = children.front(of: self.state.isSearching ? ["results"] : []) { _ in
                    search.handedOn = self.state.searchText
                    return results(self.state.searchText)
                }
                if let front { search.handOn(self.state.searchText, to: front) }
                return front
            },
            back: {
                guard self.state.isSearching else { return false }
                self.send(.searchPresentedChanged(false))
                return true
            },
            relay: children.relay
        )
    }
}

extension FolderDetailAction {
    /// A test sends each one, which catches a renamed case but not a new one left off.
    static let names = [
        "appeared", "disappeared", "deckOpened", "folderOpened", "startLessonTapped",
        "searchPresentedChanged", "searchChanged", "namingTapped", "newNameChanged",
        "namingConfirmed", "namingCancelled", "practiseFolderTapped", "practiseDeckTapped",
        "deleteDeckTapped", "deleteFolderTapped", "deleteFolderConfirmed", "deleteFolderCancelled",
    ]
}
