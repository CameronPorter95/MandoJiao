import Foundation
import VocabularyDomain

/// A few words at two levels, so plans stay small; can be told to fail.
public actor FakeHSKRepository: HSKRepository {
    private var failure: VocabularyDomainError?
    private let list: [HSKWord]

    public init(_ words: [HSKWord] = FakeHSKRepository.words) {
        list = words
    }

    /// Level 1 has 60 words, so two decks; level 2 has three, so one.
    public static let words: [HSKWord] =
        (1...60).map { HSKWord(level: 1, rank: $0, hanzi: "一\($0)", pinyin: "yī", english: "one \($0)") }
        + (1...3).map { HSKWord(level: 2, rank: $0, hanzi: "二\($0)", pinyin: "èr", english: "two \($0)") }

    /// With the vocabulary fake's failure, so a test can expect the same error from either.
    public func fail() {
        failure = FakeVocabularyRepository.failure
    }

    public func words() throws -> [HSKWord] {
        if let failure { throw failure }
        return list
    }
}
