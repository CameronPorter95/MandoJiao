import Foundation

/// How a folder lists its decks, chosen per folder.
public nonisolated struct DeckSort: Hashable, Sendable, Codable {
    public enum Field: String, CaseIterable, Sendable, Codable {
        case dateEdited
        case dateCreated
        case title
        case size
    }

    public var field: Field
    /// Latest, Z to A, or largest first when false.
    public var ascending: Bool

    public init(field: Field, ascending: Bool) {
        self.field = field
        self.ascending = ascending
    }

    /// Most recently edited first, as Notes does.
    public static let `default` = DeckSort(field: .dateEdited, ascending: false)
}

public nonisolated extension Vocabulary {
    /// Ties fall back to the title, so the order never shuffles between reads.
    func decks(in folderID: UUID?, sortedBy sort: DeckSort) -> [DeckSummary] {
        decks(in: folderID).sorted { a, b in
            let order: ComparisonResult = switch sort.field {
            case .dateEdited: compare(a.editedAt, b.editedAt)
            case .dateCreated: compare(a.createdAt, b.createdAt)
            case .title: a.displayName.localizedStandardCompare(b.displayName)
            case .size: compare(usableWordCount(in: a), usableWordCount(in: b))
            }
            if order == .orderedSame {
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            }
            return (order == .orderedAscending) == sort.ascending
        }
    }

    private func compare<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
        a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
    }
}
