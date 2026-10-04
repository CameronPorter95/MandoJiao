public struct LibraryInput {
    /// The matching lesson's floor, so this package need not know Matching.
    public let minimumMatchingWords: Int

    public init(minimumMatchingWords: Int) {
        self.minimumMatchingWords = minimumMatchingWords
    }
}
