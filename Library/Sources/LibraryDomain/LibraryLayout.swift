import Foundation

/// How the library was last left: which folders are unfolded and where, which sections of
/// each folder's screen are folded, how each folder sorts its decks, and how the list of all
/// words is sorted.
///
/// The tree and each folder's screen keep their own record, so unfolding a folder in one
/// never unfolds it in another.
public nonisolated struct LibraryLayout: Equatable, Sendable, Codable {
    public enum Scope: Hashable, Sendable, Decodable {
        case tree
        /// The subfolders shown on this folder's screen.
        case folder(UUID)
    }

    /// A section of a folder's screen that folds away.
    public enum Section: String, Hashable, Sendable, Codable {
        case folders
        case decks
    }

    public private(set) var expandedInTree: Set<UUID>
    public private(set) var expandedInFolder: [UUID: Set<UUID>]
    public private(set) var foldedSections: [UUID: Set<Section>]
    public private(set) var deckSorts: [UUID: DeckSort]
    /// Optional, so a layout saved before words could be sorted still decodes.
    private var savedWordSort: WordSort?

    public init(
        expandedInTree: Set<UUID> = [],
        expandedInFolder: [UUID: Set<UUID>] = [:],
        foldedSections: [UUID: Set<Section>] = [:],
        deckSorts: [UUID: DeckSort] = [:],
        wordSort: WordSort = .default
    ) {
        self.expandedInTree = expandedInTree
        self.expandedInFolder = expandedInFolder
        self.foldedSections = foldedSections
        self.deckSorts = deckSorts
        self.savedWordSort = wordSort == .default ? nil : wordSort
    }

    /// Folded unless listed.
    public func expanded(in scope: Scope) -> Set<UUID> {
        switch scope {
        case .tree: expandedInTree
        case .folder(let id): expandedInFolder[id] ?? []
        }
    }

    public func settingExpanded(_ folderID: UUID, _ isExpanded: Bool, in scope: Scope) -> LibraryLayout {
        var expanded = expanded(in: scope)
        if isExpanded {
            expanded.insert(folderID)
        } else {
            expanded.remove(folderID)
        }
        var copy = self
        switch scope {
        case .tree: copy.expandedInTree = expanded
        case .folder(let id): copy.expandedInFolder[id] = expanded.isEmpty ? nil : expanded
        }
        return copy
    }

    public func isFolded(_ section: Section, in folderID: UUID) -> Bool {
        foldedSections[folderID]?.contains(section) ?? false
    }

    public func toggling(_ section: Section, in folderID: UUID) -> LibraryLayout {
        var folded = foldedSections[folderID] ?? []
        if folded.remove(section) == nil { folded.insert(section) }
        var copy = self
        copy.foldedSections[folderID] = folded.isEmpty ? nil : folded
        return copy
    }

    public func deckSort(in folderID: UUID) -> DeckSort {
        deckSorts[folderID] ?? .default
    }

    public var wordSort: WordSort { savedWordSort ?? .default }

    public func settingWordSort(_ sort: WordSort) -> LibraryLayout {
        var copy = self
        copy.savedWordSort = sort == .default ? nil : sort
        return copy
    }

    public func settingDeckSort(_ sort: DeckSort, in folderID: UUID) -> LibraryLayout {
        var copy = self
        copy.deckSorts[folderID] = sort == .default ? nil : sort
        return copy
    }
}
