import Foundation

public nonisolated protocol LexiconRepository: Sendable {
    /// Nil when the lexicon cannot read the Hanzi at all.
    func suggestion(forHanzi hanzi: String) async throws -> WordSuggestion?
}
