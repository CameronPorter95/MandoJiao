import VocabularyUI

@MainActor
public struct WordEditorInput {
    /// The word to edit, or a new one to fill in.
    public let target: WordEditorTarget
    public let dictionary: DictionaryAccess

    public init(target: WordEditorTarget, dictionary: DictionaryAccess) {
        self.target = target
        self.dictionary = dictionary
    }
}
