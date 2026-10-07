import Foundation
import Testing
import DictionaryDI
import DictionaryDomain
@testable import LibraryDomain

/// The starter words against the bundled lexicon, so a regenerated `Dictionary.tsv` or an
/// edited starter word that disagrees fails here. Here rather than in the dictionary's
/// tests because the starter words are the library's.
@Suite("Starter words in the lexicon")
nonisolated struct StarterLexiconTests {
    private func suggest(_ hanzi: String) async throws -> WordSuggestion? {
        try await DictionaryRepositoryFactory.makeLexiconRepository().suggestion(forHanzi: hanzi)
    }

    @Test("cost: every starter word's pinyin matches, except 对不起's written tone on 不")
    func starterWords() async throws {
        let comparable = { (pinyin: String) in
            pinyin.lowercased().filter { $0 != " " && $0 != "'" }
        }
        var disagreements: [String] = []
        for entry in SampleVocabulary.deckPlan.flatMap(\.entries) {
            let suggested = try await suggest(entry.hanzi)?.pinyin ?? ""
            if comparable(suggested) != comparable(entry.pinyin) { disagreements.append(entry.hanzi) }
        }
        #expect(disagreements == ["对不起"])
    }
}
