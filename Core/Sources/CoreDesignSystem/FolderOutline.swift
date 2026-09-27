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

/// A Notes-style tree of rows that can be dragged into, between and out of each other.
///
/// UIKit on iOS, because SwiftUI's reordering cannot drop one row onto another. On macOS
/// it is a plain indented list with no dragging, so feature views still build there.
public struct FolderOutline<ID: Hashable & Sendable>: View {
    let nodes: [OutlineNode<ID>]
    let isEditing: Bool
    let canMove: (OutlineMove<ID>) -> Bool
    let onMove: (OutlineMove<ID>) -> Void
    let onSelect: (ID) -> Void
    let actions: (ID) -> [OutlineAction]

    public init(
        nodes: [OutlineNode<ID>],
        isEditing: Bool,
        canMove: @escaping (OutlineMove<ID>) -> Bool,
        onMove: @escaping (OutlineMove<ID>) -> Void,
        onSelect: @escaping (ID) -> Void,
        actions: @escaping (ID) -> [OutlineAction]
    ) {
        self.nodes = nodes
        self.isEditing = isEditing
        self.canMove = canMove
        self.onMove = onMove
        self.onSelect = onSelect
        self.actions = actions
    }

    public var body: some View {
        #if os(iOS)
        OutlineCollection(outline: self)
        #else
        List {
            ForEach(Self.flattened(nodes), id: \.node.id) { row in
                Button { onSelect(row.node.id) } label: {
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

    func makeCoordinator() -> OutlineCoordinator<ID> {
        OutlineCoordinator(outline: outline)
    }

    func makeUIView(context: Context) -> UICollectionView {
        context.coordinator.makeCollectionView()
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.outline = outline
        context.coordinator.apply(outline.nodes)
        if collectionView.isEditing != outline.isEditing {
            collectionView.isEditing = outline.isEditing
        }
    }
}

private final class OutlineCoordinator<ID: Hashable & Sendable>: NSObject, UICollectionViewDelegate,
    UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    var outline: FolderOutline<ID>
    private var dataSource: UICollectionViewDiffableDataSource<Int, ID>!
    private var nodesByID: [ID: OutlineNode<ID>] = [:]
    private var applied: [OutlineNode<ID>]?
    private var collapsed: Set<ID> = []
    /// Where a drop between rows would land. UIKit's own gap is never opened, because
    /// shifting rows under the finger changes which row it is over and the drop flickers.
    private let insertionLine = UIView()

    init(outline: FolderOutline<ID>) {
        self.outline = outline
    }

    func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .insetGrouped))
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        insertionLine.backgroundColor = .tintColor
        insertionLine.layer.cornerRadius = 1.5
        insertionLine.isHidden = true
        collectionView.addSubview(insertionLine)

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, ID> { [weak self] cell, _, id in
            guard let self, let node = nodesByID[id] else { return }
            var content = cell.defaultContentConfiguration()
            content.text = node.title
            content.image = UIImage(systemName: node.systemImage)
            cell.contentConfiguration = content

            var accessories: [UICellAccessory] = []
            let actions = outline.actions(id)
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
            cell.accessories = accessories
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }

        dataSource.sectionSnapshotHandlers.willCollapseItem = { [weak self] id in self?.collapsed.insert(id) }
        dataSource.sectionSnapshotHandlers.willExpandItem = { [weak self] id in self?.collapsed.remove(id) }

        return collectionView
    }

    func apply(_ nodes: [OutlineNode<ID>]) {
        guard nodes != applied else { return }
        let animate = applied != nil
        applied = nodes
        nodesByID = [:]
        var snapshot = NSDiffableDataSourceSectionSnapshot<ID>()
        func add(_ nodes: [OutlineNode<ID>], to parent: ID?) {
            snapshot.append(nodes.map(\.id), to: parent)
            for node in nodes {
                nodesByID[node.id] = node
                add(node.children, to: node.id)
            }
        }
        add(nodes, to: nil)
        snapshot.expand(Array(nodesByID.keys.filter { !collapsed.contains($0) }))
        dataSource.apply(snapshot, to: 0, animatingDifferences: animate)
        var updated = dataSource.snapshot()
        updated.reconfigureItems(updated.itemIdentifiers)
        dataSource.apply(updated, animatingDifferences: false)
    }

    // MARK: Selection

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        outline.onSelect(id)
    }

    // MARK: Drag and drop

    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return [] }
        let item = UIDragItem(itemProvider: NSItemProvider())
        item.localObject = id
        return [item]
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        true
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        session.localDragSession != nil
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
        let rows = dataSource.snapshot(for: 0).visibleItems
        let y: CGFloat
        let level: Int
        switch drop {
        case .before(let target):
            guard let indexPath = dataSource.indexPath(for: target),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame
            else { insertionLine.isHidden = true; return }
            y = frame.minY
            level = dataSource.snapshot(for: 0).level(of: target)
        case .atEnd:
            guard let last = rows.last, let indexPath = dataSource.indexPath(for: last),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame
            else { insertionLine.isHidden = true; return }
            y = frame.maxY
            level = 0
        case .into:
            insertionLine.isHidden = true
            return
        }
        let leading = collectionView.layoutMargins.left + 20 + CGFloat(level) * 23
        let trailing = collectionView.bounds.width - collectionView.layoutMargins.right - 20
        insertionLine.frame = CGRect(x: leading, y: y - 1.5, width: max(0, trailing - leading), height: 3)
        insertionLine.isHidden = false
        collectionView.bringSubviewToFront(insertionLine)
    }

    /// The middle half of a row drops onto it. Above or below that, the drop is in the gap.
    private func resolve(_ session: UIDropSession, in collectionView: UICollectionView) -> (OutlineDrop<ID>, OutlineMove<ID>)? {
        guard let item = session.localDragSession?.items.first?.localObject as? ID else { return nil }
        let visible = dataSource.snapshot(for: 0).visibleItems
        let location = session.location(in: collectionView)

        let drop: OutlineDrop<ID>
        if let indexPath = collectionView.indexPathForItem(at: location),
           let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame,
           let target = dataSource.itemIdentifier(for: indexPath) {
            let fraction = (location.y - frame.minY) / max(frame.height, 1)
            switch fraction {
            case 0.25..<0.75 where target != item:
                drop = .into(target)
            case ..<0.25:
                drop = OutlineDropResolver.drop(atGap: indexPath.item, visible: visible, moving: item, in: outline.nodes)
            default:
                drop = OutlineDropResolver.drop(atGap: indexPath.item + 1, visible: visible, moving: item, in: outline.nodes)
            }
        } else {
            let gap = location.y < (collectionView.visibleCells.map(\.frame.minY).min() ?? 0) ? 0 : visible.count
            drop = OutlineDropResolver.drop(atGap: gap, visible: visible, moving: item, in: outline.nodes)
        }
        guard let move = OutlineDropResolver.move(item, dropped: drop, in: outline.nodes) else { return nil }
        return (drop, move)
    }
}
#endif
