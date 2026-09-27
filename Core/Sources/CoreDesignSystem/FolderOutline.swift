import SwiftUI

/// An action in a row's ⋯ menu.
public struct OutlineAction {
    public let title: String
    public let systemImage: String
    public let isDestructive: Bool
    public let perform: () -> Void

    public init(_ title: String, systemImage: String, isDestructive: Bool = false, perform: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.perform = perform
    }
}

/// A fixed row above the tree, such as "All words". It can be selected but not moved.
public nonisolated struct OutlinePinnedRow: Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

public nonisolated enum OutlineSelection<ID: Hashable & Sendable>: Hashable, Sendable {
    case pinned(String)
    case node(ID)
}

/// A Notes-style tree of rows that can be dragged into, between and out of each other.
///
/// UIKit on iOS, because SwiftUI's reordering cannot drop one row onto another. On macOS
/// it is a plain indented list with no dragging, so feature views still build there.
public struct FolderOutline<ID: Hashable & Sendable>: View {
    let pinned: [OutlinePinnedRow]
    let nodes: [OutlineNode<ID>]
    let selection: OutlineSelection<ID>?
    let expanded: Set<ID>
    let isEditing: Bool
    let canMove: (OutlineMove<ID>) -> Bool
    let onMove: (OutlineMove<ID>) -> Void
    let onSelect: (OutlineSelection<ID>) -> Void
    let onExpand: (ID, Bool) -> Void
    let actions: (ID) -> [OutlineAction]
    let onPractise: (ID) -> Void
    let onDelete: (ID) -> Void

    /// `selection` is highlighted only at regular width, where the next column shows it.
    /// Rows are folded unless `expanded` holds them, and `onExpand` reports every change.
    /// `onPractise` and `onDelete` are the leading and trailing swipes on a row of the tree;
    /// pinned rows have neither.
    public init(
        pinned: [OutlinePinnedRow] = [],
        nodes: [OutlineNode<ID>],
        selection: OutlineSelection<ID>?,
        expanded: Set<ID>,
        isEditing: Bool,
        canMove: @escaping (OutlineMove<ID>) -> Bool,
        onMove: @escaping (OutlineMove<ID>) -> Void,
        onSelect: @escaping (OutlineSelection<ID>) -> Void,
        onExpand: @escaping (ID, Bool) -> Void,
        actions: @escaping (ID) -> [OutlineAction],
        onPractise: @escaping (ID) -> Void,
        onDelete: @escaping (ID) -> Void
    ) {
        self.pinned = pinned
        self.nodes = nodes
        self.selection = selection
        self.expanded = expanded
        self.isEditing = isEditing
        self.canMove = canMove
        self.onMove = onMove
        self.onSelect = onSelect
        self.onExpand = onExpand
        self.actions = actions
        self.onPractise = onPractise
        self.onDelete = onDelete
    }

    public var body: some View {
        #if os(iOS)
        OutlineCollection(outline: self)
        #else
        List {
            ForEach(pinned, id: \.id) { row in
                Button { onSelect(.pinned(row.id)) } label: { Label(row.title, systemImage: row.systemImage) }
                    .buttonStyle(.plain)
            }
            ForEach(Self.flattened(nodes), id: \.node.id) { row in
                Button { onSelect(.node(row.node.id)) } label: {
                    Label(row.node.title, systemImage: row.node.systemImage)
                        .padding(.leading, CGFloat(row.depth) * 16)
                }
                .buttonStyle(.plain)
            }
        }
        #endif
    }

    static func flattened(_ nodes: [OutlineNode<ID>], depth: Int = 0) -> [(node: OutlineNode<ID>, depth: Int)] {
        nodes.flatMap { [(node: $0, depth: depth)] + flattened($0.children, depth: depth + 1) }
    }
}

#if os(iOS)
import UIKit

private struct OutlineCollection<ID: Hashable & Sendable>: UIViewRepresentable {
    let outline: FolderOutline<ID>
    @Environment(\.horizontalSizeClass) private var sizeClass

    func makeCoordinator() -> OutlineCoordinator<ID> {
        OutlineCoordinator(outline: outline)
    }

    func makeUIView(context: Context) -> UICollectionView {
        context.coordinator.makeCollectionView()
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.outline = outline
        context.coordinator.apply(pinned: outline.pinned, nodes: outline.nodes, expanded: outline.expanded)
        if collectionView.isEditing != outline.isEditing {
            collectionView.isEditing = outline.isEditing
        }
        context.coordinator.highlight(sizeClass == .regular ? outline.selection : nil, in: collectionView)
    }
}

private nonisolated enum OutlineItem<ID: Hashable & Sendable>: Hashable, Sendable {
    case pinned(String)
    case node(ID)

    var selection: OutlineSelection<ID> {
        switch self {
        case .pinned(let id): .pinned(id)
        case .node(let id): .node(id)
        }
    }
}

private final class OutlineCoordinator<ID: Hashable & Sendable>: NSObject, UICollectionViewDelegate,
    UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    private typealias Item = OutlineItem<ID>
    private static var pinnedSection: Int { 0 }
    private static var treeSection: Int { 1 }

    var outline: FolderOutline<ID>
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private var nodesByID: [ID: OutlineNode<ID>] = [:]
    private var pinnedByID: [String: OutlinePinnedRow] = [:]
    private var applied: (pinned: [OutlinePinnedRow], nodes: [OutlineNode<ID>], expanded: Set<ID>)?
    /// Where a drop between rows would land. UIKit's own gap is never opened, because
    /// shifting rows under the finger changes which row it is over and the drop flickers.
    private let insertionLine = UIView()

    init(outline: FolderOutline<ID>) {
        self.outline = outline
    }

    func makeCollectionView() -> UICollectionView {
        var list = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        list.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, case .node(let id) = dataSource.itemIdentifier(for: indexPath) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
                self?.outline.onDelete(id)
                done(true)
            }
            delete.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [delete])
        }
        list.leadingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, case .node(let id) = dataSource.itemIdentifier(for: indexPath) else { return nil }
            let practise = UIContextualAction(style: .normal, title: "Practise") { [weak self] _, _, done in
                self?.outline.onPractise(id)
                done(true)
            }
            practise.image = UIImage(systemName: "play.fill")
            practise.backgroundColor = UIColor(Theme.accent)
            return UISwipeActionsConfiguration(actions: [practise])
        }
        let layout = UICollectionViewCompositionalLayout.list(using: list)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        insertionLine.backgroundColor = .tintColor
        insertionLine.layer.cornerRadius = 1.5
        insertionLine.isHidden = true
        collectionView.addSubview(insertionLine)

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            switch item {
            case .pinned(let id):
                guard let row = pinnedByID[id] else { return }
                content.text = row.title
                content.image = UIImage(systemName: row.systemImage)
                cell.contentConfiguration = content
                cell.accessories = []
            case .node(let id):
                guard let node = nodesByID[id] else { return }
                content.text = node.title
                content.image = UIImage(systemName: node.systemImage)
                cell.contentConfiguration = content
                cell.accessories = accessories(for: node)
            }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }

        dataSource.sectionSnapshotHandlers.willCollapseItem = { [weak self] item in
            if case .node(let id) = item { self?.outline.onExpand(id, false) }
        }
        dataSource.sectionSnapshotHandlers.willExpandItem = { [weak self] item in
            if case .node(let id) = item { self?.outline.onExpand(id, true) }
        }
        return collectionView
    }

    private func accessories(for node: OutlineNode<ID>) -> [UICellAccessory] {
        var accessories: [UICellAccessory] = []
        let actions = outline.actions(node.id)
        if !actions.isEmpty {
            let menu = UIMenu(children: actions.map { action in
                UIAction(
                    title: action.title,
                    image: UIImage(systemName: action.systemImage),
                    attributes: action.isDestructive ? .destructive : []
                ) { _ in action.perform() }
            })
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
            button.menu = menu
            button.showsMenuAsPrimaryAction = true
            accessories.append(.customView(configuration: .init(customView: button, placement: .trailing(displayed: .always))))
        }
        if !node.children.isEmpty {
            accessories.append(.outlineDisclosure())
        }
        accessories.append(.reorder(displayed: .whenEditing))
        return accessories
    }

    func apply(pinned: [OutlinePinnedRow], nodes: [OutlineNode<ID>], expanded: Set<ID>) {
        if let applied, applied.pinned == pinned, applied.nodes == nodes, applied.expanded == expanded { return }
        let animate = applied != nil
        applied = (pinned, nodes, expanded)
        pinnedByID = Dictionary(uniqueKeysWithValues: pinned.map { ($0.id, $0) })
        nodesByID = [:]

        var pinnedSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
        pinnedSnapshot.append(pinned.map { .pinned($0.id) })
        var tree = NSDiffableDataSourceSectionSnapshot<Item>()
        func add(_ nodes: [OutlineNode<ID>], to parent: ID?) {
            tree.append(nodes.map { .node($0.id) }, to: parent.map(Item.node))
            for node in nodes {
                nodesByID[node.id] = node
                add(node.children, to: node.id)
            }
        }
        add(nodes, to: nil)
        tree.expand(nodesByID.keys.filter(expanded.contains).map(Item.node))

        dataSource.apply(pinnedSnapshot, to: Self.pinnedSection, animatingDifferences: animate)
        dataSource.apply(tree, to: Self.treeSection, animatingDifferences: animate)
        var updated = dataSource.snapshot()
        updated.reconfigureItems(updated.itemIdentifiers)
        dataSource.apply(updated, animatingDifferences: false)
    }

    // MARK: Selection

    func highlight(_ selection: OutlineSelection<ID>?, in collectionView: UICollectionView) {
        let target: Item? = selection.map {
            switch $0 {
            case .pinned(let id): .pinned(id)
            case .node(let id): .node(id)
            }
        }
        let indexPath = target.flatMap(dataSource.indexPath(for:))
        for selected in collectionView.indexPathsForSelectedItems ?? [] where selected != indexPath {
            collectionView.deselectItem(at: selected, animated: false)
        }
        if let indexPath, collectionView.indexPathsForSelectedItems?.contains(indexPath) != true {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if collectionView.traitCollection.horizontalSizeClass != .regular {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
        outline.onSelect(item.selection)
    }

    // MARK: Drag and drop

    private var visibleNodes: [ID] {
        dataSource.snapshot(for: Self.treeSection).visibleItems.compactMap {
            if case .node(let id) = $0 { id } else { nil }
        }
    }

    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard case .node(let id) = dataSource.itemIdentifier(for: indexPath) else { return [] }
        let item = UIDragItem(itemProvider: NSItemProvider())
        item.localObject = id
        return [item]
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        true
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        session.localDragSession?.items.first?.localObject is ID
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard let (drop, move) = resolve(session, in: collectionView), outline.canMove(move) else {
            insertionLine.isHidden = true
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        if case .into = drop {
            insertionLine.isHidden = true
            return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
        }
        showInsertionLine(for: drop, in: collectionView)
        return UICollectionViewDropProposal(operation: .move, intent: .unspecified)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        insertionLine.isHidden = true
        guard let (_, move) = resolve(coordinator.session, in: collectionView), outline.canMove(move) else { return }
        outline.onMove(move)
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        insertionLine.isHidden = true
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        insertionLine.isHidden = true
    }

    /// A line above the row the item would go before, indented to that row's level.
    private func showInsertionLine(for drop: OutlineDrop<ID>, in collectionView: UICollectionView) {
        let tree = dataSource.snapshot(for: Self.treeSection)
        let row: Item?
        let level: Int
        let atBottom: Bool
        switch drop {
        case .before(let target):
            row = .node(target)
            level = tree.level(of: .node(target))
            atBottom = false
        case .atEnd:
            row = tree.visibleItems.last
            level = 0
            atBottom = true
        case .into:
            insertionLine.isHidden = true
            return
        }
        guard let row, let indexPath = dataSource.indexPath(for: row),
              let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame
        else {
            insertionLine.isHidden = true
            return
        }
        let leading = collectionView.layoutMargins.left + 20 + CGFloat(level) * 23
        let trailing = collectionView.bounds.width - collectionView.layoutMargins.right - 20
        let y = atBottom ? frame.maxY : frame.minY
        insertionLine.frame = CGRect(x: leading, y: y - 1.5, width: max(0, trailing - leading), height: 3)
        insertionLine.isHidden = false
        collectionView.bringSubviewToFront(insertionLine)
    }

    /// The middle half of a row drops onto it. Above or below that, the drop is in the gap.
    /// Anywhere over the pinned rows counts as the gap above the tree.
    private func resolve(_ session: UIDropSession, in collectionView: UICollectionView) -> (OutlineDrop<ID>, OutlineMove<ID>)? {
        guard let item = session.localDragSession?.items.first?.localObject as? ID else { return nil }
        let visible = visibleNodes
        let location = session.location(in: collectionView)
        let gap = { (gap: Int) in OutlineDropResolver.drop(atGap: gap, visible: visible, moving: item, in: self.outline.nodes) }

        let drop: OutlineDrop<ID>
        if let indexPath = collectionView.indexPathForItem(at: location), indexPath.section == Self.pinnedSection {
            drop = gap(0)
        } else if let indexPath = collectionView.indexPathForItem(at: location),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame,
                  case .node(let target) = dataSource.itemIdentifier(for: indexPath) {
            let fraction = (location.y - frame.minY) / max(frame.height, 1)
            switch fraction {
            case 0.25..<0.75 where target != item: drop = .into(target)
            case ..<0.25: drop = gap(indexPath.item)
            default: drop = gap(indexPath.item + 1)
            }
        } else {
            let firstTreeRow = visible.first.flatMap { dataSource.indexPath(for: .node($0)) }
                .flatMap { collectionView.layoutAttributesForItem(at: $0)?.frame.minY } ?? 0
            drop = gap(location.y < firstTreeRow ? 0 : visible.count)
        }
        guard let move = OutlineDropResolver.move(item, dropped: drop, in: outline.nodes) else { return nil }
        return (drop, move)
    }
}
#endif
