import CoreUI
import Foundation

extension FolderDetailViewModel {
    public func driver(navigation: FolderDetailNavigation) -> ScreenDriver {
        ScreenDriver(
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
            follow: navigation.follow
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
