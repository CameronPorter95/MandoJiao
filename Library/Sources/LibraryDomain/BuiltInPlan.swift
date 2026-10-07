import Foundation

/// Folders and decks the app supplies, each found again by its key however it is renamed.
/// Installing one creates only what is missing, so it both adds and restores.
public nonisolated struct BuiltInPlan: Equatable, Sendable {
    public struct Folder: Equatable, Sendable {
        public let key: String
        public let name: String
        /// Nil for the top level.
        public let parentKey: String?
        /// Among its siblings when it is created.
        public let position: Int
    }

    public struct Deck: Equatable, Sendable {
        public let key: String
        public let name: String
        public let folderKey: String
        public let position: Int
        /// In deck order. A word already in the library with the same Hanzi is used instead.
        public let words: [WordDraft]
    }

    public let folders: [Folder]
    public let decks: [Deck]

    public init(folders: [Folder], decks: [Deck]) {
        self.folders = folders
        self.decks = decks
    }

    /// The decks the library does not have, whether never added or deleted since.
    public func missingDecks(in vocabulary: Vocabulary) -> [Deck] {
        let present = Set(vocabulary.decks.compactMap(\.builtInKey))
        return decks.filter { !present.contains($0.key) }
    }
}
