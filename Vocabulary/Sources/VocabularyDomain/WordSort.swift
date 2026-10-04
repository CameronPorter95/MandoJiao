import Foundation

/// How the library's lists of words are ordered: all of them, a folder's, or a deck's.
public nonisolated struct WordSort: Hashable, Sendable, Codable {
    public enum Field: String, CaseIterable, Sendable, Codable {
        case english
        case pinyin
        case dateAdded
        case mistakes
    }

    public var field: Field
    /// A to Z, oldest first, or fewest mistakes first when true.
    public var ascending: Bool

    public init(field: Field, ascending: Bool) {
        self.field = field
        self.ascending = ascending
    }

    /// English A to Z, as the list always was.
    public static let `default` = WordSort(field: .english, ascending: true)
}

public nonisolated extension Vocabulary {
    func words(sortedBy sort: WordSort) -> [Word] {
        Self.sorted(words, by: sort)
    }

    /// Every word in every deck beneath the folder, as a lesson from it draws them.
    func words(in folder: FolderSummary, sortedBy sort: WordSort) -> [Word] {
        Self.sorted(words(in: folder), by: sort)
    }

    func words(in deck: DeckSummary, sortedBy sort: WordSort) -> [Word] {
        Self.sorted(words(in: deck), by: sort)
    }

    /// Ties fall back to the English, so the order never shuffles between reads.
    ///
    /// Each headline is made plain once, before sorting. Made plain in the comparison, 565
    /// words, HSK 1 and 2 and Starter, took 85 ms to sort by English; made once, 5.5 ms.
    private static func sorted(_ words: [Word], by sort: WordSort) -> [Word] {
        words
            .map { (word: $0, english: Gloss.plain($0.english)) }
            .sorted { a, b in
                let order: ComparisonResult = switch sort.field {
                case .english: Self.english(a.english, b.english)
                case .pinyin: Self.pinyin(a.word, b.word)
                case .dateAdded: Self.compare(a.word.createdAt, b.word.createdAt)
                case .mistakes: Self.compare(a.word.missCount, b.word.missCount)
                }
                if order == .orderedSame { return Self.english(a.english, b.english) == .orderedAscending }
                return (order == .orderedAscending) == sort.ascending
            }
            .map(\.word)
    }

    /// By the headline as a tile shows it, made plain: "(general classifier)" files under G,
    /// and case is ignored, where a plain comparison put every bracketed headline first and
    /// "Europe" before "apple".
    private static func english(_ a: String, _ b: String) -> ComparisonResult {
        a.localizedStandardCompare(b)
    }

    /// Tones and case ignored, then tones deciding, so hē and hè sit together.
    private static func pinyin(_ a: Word, _ b: Word) -> ComparisonResult {
        let loose = a.pinyin.compare(b.pinyin, options: [.caseInsensitive, .diacriticInsensitive])
        return loose == .orderedSame ? a.pinyin.localizedStandardCompare(b.pinyin) : loose
    }

    private static func compare<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
        a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
    }
}
