import Foundation
import CoreDomain
import VocabularyDomain

/// A dictionary that knows only the entries it is given, records every lookup, and can be
/// told to fail.
public actor FakeDictionaryRepository: DictionaryRepository {
    public private(set) var lookups: [String] = []
    private let entries: [DictionaryEntry]
    private var failure: VocabularyDomainError?

    public init(_ entries: [DictionaryEntry] = FakeDictionaryRepository.words) {
        self.entries = entries
    }

    public static let words = [
        entry("喝", "hē", preferred: true, "to drink", "to shout (of approval)"),
        entry("喝", "hè", preferred: false, "to shout loudly"),
        entry("银行", "yínháng", preferred: true, "bank (CL:家[jia1],個|个[ge4])", "bank (financial institution)"),
        entry("银", "yín", preferred: true, "silver", "silver-colored"),
        entry("行", "xíng", preferred: true, "to walk", "okay"),
        entry("行", "háng", preferred: false, "row, line", "profession"),
    ]

    public static let failure = VocabularyDomainError.unexpected(
        model: DomainErrorModel(domain: "test", code: 3, description: "dictionary failed")
    )

    public static func entry(_ hanzi: String, _ pinyin: String, preferred: Bool, _ senses: String...) -> DictionaryEntry {
        DictionaryEntry(simplified: hanzi, traditional: hanzi, pinyin: pinyin, isPreferred: preferred, senses: senses)
    }

    public func failLookups(with error: VocabularyDomainError? = FakeDictionaryRepository.failure) {
        failure = error
    }

    public private(set) var searches: [String] = []

    /// Headwords holding the query, or with a sense holding it, in the order given.
    public func search(_ query: String, limit: Int) throws -> [DictionarySearchResult] {
        searches.append(query)
        if let failure { throw failure }
        return entries.filter { $0.simplified.contains(query) || $0.senses.contains { $0.contains(query) } }
            .prefix(limit)
            .map { DictionarySearchResult(entry: $0) }
    }

    public func entries(forHanzi hanzi: String) throws -> [DictionaryEntry] {
        lookups.append(hanzi)
        if let failure { throw failure }
        return entries.filter { $0.simplified == hanzi }.sorted { $0.isPreferred && !$1.isPreferred }
    }
}
