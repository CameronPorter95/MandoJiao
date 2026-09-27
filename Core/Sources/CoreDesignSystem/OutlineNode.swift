import Foundation

/// One row of a `FolderOutline`, with its children beneath it.
public nonisolated struct OutlineNode<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    public let id: ID
    public let title: String
    public let systemImage: String
    public let children: [OutlineNode]

    public init(id: ID, title: String, systemImage: String = "folder", children: [OutlineNode] = []) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.children = children
    }
}

/// Where a dragged row was let go.
public nonisolated enum OutlineDrop<ID: Hashable & Sendable>: Hashable, Sendable {
    /// Onto a row: the item becomes its last child.
    case into(ID)
    /// In the gap above a row: the item joins that row's parent, just before it.
    case before(ID)
    /// Below every row: the item goes last at the top level.
    case atEnd
}

/// A move the outline reports. `index` counts the new siblings without the item itself.
public nonisolated struct OutlineMove<ID: Hashable & Sendable>: Hashable, Sendable {
    public let item: ID
    /// Nil for the top level.
    public let parent: ID?
    public let index: Int

    public init(item: ID, parent: ID?, index: Int) {
        self.item = item
        self.parent = parent
        self.index = index
    }
}

/// Turns a drop into a move. Separate from the view so the rules run headlessly.
public nonisolated enum OutlineDropResolver {
    /// Nil for a drop that changes nothing, or would put the item inside itself.
    public static func move<ID>(_ item: ID, dropped drop: OutlineDrop<ID>, in roots: [OutlineNode<ID>]) -> OutlineMove<ID>? {
        let tree = OutlineTree(roots)
        guard tree.contains(item) else { return nil }

        let move: OutlineMove<ID>
        switch drop {
        case .into(let target):
            guard tree.contains(target) else { return nil }
            move = OutlineMove(item: item, parent: target, index: tree.children(of: target).filter { $0 != item }.count)
        case .before(let target):
            guard target != item, tree.contains(target) else { return nil }
            let parent = tree.parent(of: target)
            let siblings = tree.children(of: parent).filter { $0 != item }
            guard let index = siblings.firstIndex(of: target) else { return nil }
            move = OutlineMove(item: item, parent: parent, index: index)
        case .atEnd:
            move = OutlineMove(item: item, parent: nil, index: tree.children(of: nil).filter { $0 != item }.count)
        }

        if let parent = move.parent, parent == item || tree.isInside(parent, item) { return nil }
        let unchanged = move.parent == tree.parent(of: item)
            && move.index == tree.children(of: move.parent).firstIndex(of: item)
        return unchanged ? nil : move
    }

    /// The drop for a gap in the visible rows, where gap `i` sits above visible row `i`.
    /// The dragged row and everything beneath it are skipped, since it is lifted out.
    public static func drop<ID>(atGap gap: Int, visible: [ID], moving item: ID, in roots: [OutlineNode<ID>]) -> OutlineDrop<ID> {
        let tree = OutlineTree(roots)
        let below = visible.dropFirst(max(0, gap)).first { $0 != item && !tree.isInside($0, item) }
        return below.map(OutlineDrop.before) ?? .atEnd
    }
}

private nonisolated struct OutlineTree<ID: Hashable & Sendable> {
    private var parents: [ID: ID?] = [:]
    private var childrenByParent: [ID?: [ID]] = [:]

    init(_ roots: [OutlineNode<ID>]) {
        func add(_ nodes: [OutlineNode<ID>], under parent: ID?) {
            childrenByParent[parent] = nodes.map(\.id)
            for node in nodes {
                parents[node.id] = .some(parent)
                add(node.children, under: node.id)
            }
        }
        add(roots, under: nil)
    }

    func contains(_ id: ID) -> Bool { parents[id] != nil }
    func parent(of id: ID) -> ID? { parents[id] ?? nil }
    func children(of parent: ID?) -> [ID] { childrenByParent[parent] ?? [] }

    /// True when `id` sits somewhere beneath `ancestor`.
    func isInside(_ id: ID, _ ancestor: ID) -> Bool {
        var next = parent(of: id)
        while let current = next {
            if current == ancestor { return true }
            next = parent(of: current)
        }
        return false
    }
}
