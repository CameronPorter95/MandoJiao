import CoreDomain
import Foundation
import VocabularyDomain

actor LexiconRepositoryImpl: LexiconRepository {
    private let source: any LexiconSource
    private var loading: Task<LexiconTable, any Error>?

    init(source: any LexiconSource) {
        self.source = source
    }

    /// A phrase the lexicon lacks gets pinyin from its longest known pieces, and no English.
    func suggestion(forHanzi hanzi: String) async throws -> WordSuggestion? {
        do {
            let table = try await table()
            if let entry = table.suggestion(hanzi) { return entry }

            let characters = Array(hanzi)
            var pieces: [String] = []
            var start = 0
            while start < characters.count {
                let longest = min(table.longestHeadword, characters.count - start)
                guard longest > 0 else { return nil }
                let match = (1...longest).reversed().lazy.compactMap { length in
                    table.suggestion(String(characters[start..<start + length])).map { (length, $0) }
                }.first
                guard let (length, entry) = match else { return nil }
                pieces.append(entry.pinyin)
                start += length
            }
            return WordSuggestion(hanzi: hanzi, pinyin: pieces.joined(separator: " "), english: "")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VocabularyDomainError.unexpected(model: DomainErrorModel(error))
        }
    }

    /// Loads once however many lookups arrive while it runs, and retries after a failure.
    private func table() async throws -> LexiconTable {
        if loading == nil {
            loading = Task { [source] in try await source.entries() }
        }
        do {
            return try await loading!.value
        } catch {
            loading = nil
            throw error
        }
    }
}

/// The one lexicon for the app's lifetime, so it is read from disk once.
public nonisolated enum Lexicon {
    public static let repository: any LexiconRepository = LexiconRepositoryImpl(source: DictionaryLexiconSource())
}
