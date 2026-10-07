import DictionaryDomain

@MainActor
public struct DictionaryInput {
    /// The page to open on.
    public let headword: DictionaryHeadword
    /// Where each reading can be added to the vocabulary, or opened there when it is
    /// already saved. Nil in the word editor's own dictionary, where adding would open an
    /// editor over the editor.
    public let vocabulary: DictionaryVocabulary?

    public init(headword: DictionaryHeadword, vocabulary: DictionaryVocabulary?) {
        self.headword = headword
        self.vocabulary = vocabulary
    }
}
