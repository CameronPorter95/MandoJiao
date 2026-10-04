import VocabularyUI

@MainActor
public struct DictionaryInput {
    /// The page to open on.
    public let headword: DictionaryHeadword
    /// Whether each reading can be added to the vocabulary, or opened there when it is
    /// already saved.
    public let addsToVocabulary: Bool

    public init(headword: DictionaryHeadword, addsToVocabulary: Bool) {
        self.headword = headword
        self.addsToVocabulary = addsToVocabulary
    }
}
