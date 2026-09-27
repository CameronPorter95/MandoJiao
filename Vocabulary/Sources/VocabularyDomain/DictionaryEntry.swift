import Foundation

/// One reading of a headword in the dictionary, with every sense it has. Never edited.
public nonisolated struct DictionaryEntry: Equatable, Sendable {
    public let simplified: String
    public let traditional: String
    public let pinyin: String
    /// The reading suggestions use when a headword has several.
    public let isPreferred: Bool
    /// As the dictionary gives them, asides included, most common first.
    public let senses: [String]

    public init(simplified: String, traditional: String, pinyin: String, isPreferred: Bool, senses: [String]) {
        self.simplified = simplified
        self.traditional = traditional
        self.pinyin = pinyin
        self.isPreferred = isPreferred
        self.senses = senses
    }
}

public nonisolated protocol DictionaryRepository: Sendable {
    /// Every reading of the headword, the preferred one first. Empty when it is not a headword.
    func entries(forHanzi hanzi: String) async throws -> [DictionaryEntry]
}
