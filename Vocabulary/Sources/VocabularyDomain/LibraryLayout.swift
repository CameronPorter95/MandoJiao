import Foundation

/// How the library was last left: which folders are unfolded, and where.
///
/// The tree and each folder's screen keep their own record, so unfolding a folder in one
/// never unfolds it in another.
public nonisolated struct LibraryLayout: Equatable, Sendable, Codable {
    public enum Scope: Hashable, Sendable {
        case tree
        /// The subfolders shown on this folder's screen.
        case folder(UUID)
    }

    public private(set) var expandedInTree: Set<UUID>
    public private(set) var expandedInFolder: [UUID: Set<UUID>]
    /// Folders whose screen has its Folders section folded away.
    public private(set) var foldedSections: Set<UUID>

    public init(
        expandedInTree: Set<UUID> = [],
        expandedInFolder: [UUID: Set<UUID>] = [:],
        foldedSections: Set<UUID> = []
    ) {
        self.expandedInTree = expandedInTree
        self.expandedInFolder = expandedInFolder
        self.foldedSections = foldedSections
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

    public func togglingSection(of folderID: UUID) -> LibraryLayout {
        var copy = self
        if copy.foldedSections.remove(folderID) == nil { copy.foldedSections.insert(folderID) }
        return copy
    }
}
