public struct LibraryInput {
    /// The matching lesson's floor, so this package need not know Matching.
    public let minimumMatchingWords: Int
    public let dictionary: DictionaryAccess

    public init(minimumMatchingWords: Int, dictionary: DictionaryAccess) {
        self.minimumMatchingWords = minimumMatchingWords
        self.dictionary = dictionary
    }
}
