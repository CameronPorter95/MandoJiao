import Foundation
import CoreDomain
import VocabularyDomain

/// A lexicon that knows only the words it is given, records every lookup, and can be
/// told to fail.
public actor FakeLexiconRepository: LexiconRepository {
    public private(set) var lookups: [String] = []
    private let suggestions: [String: WordSuggestion]
    private var failure: VocabularyDomainError?

    public init(_ suggestions: [WordSuggestion] = FakeLexiconRepository.words) {
        self.suggestions = Dictionary(uniqueKeysWithValues: suggestions.map { ($0.hanzi, $0) })
    }

    public static let words = [
        WordSuggestion(hanzi: "喝", pinyin: "hē", english: "to drink"),
        WordSuggestion(hanzi: "银行", pinyin: "yínháng", english: "bank"),
        WordSuggestion(hanzi: "银", pinyin: "yín", english: "silver"),
        WordSuggestion(hanzi: "水", pinyin: "shuǐ", english: "water, river"),
    ]

    public static let failure = VocabularyDomainError.unexpected(
        model: DomainErrorModel(domain: "test", code: 2, description: "lexicon failed")
    )

    public func failLookups(with error: VocabularyDomainError? = FakeLexiconRepository.failure) {
        failure = error
    }

    public func suggestion(forHanzi hanzi: String) throws -> WordSuggestion? {
        lookups.append(hanzi)
        if let failure { throw failure }
        return suggestions[hanzi]
    }
}
