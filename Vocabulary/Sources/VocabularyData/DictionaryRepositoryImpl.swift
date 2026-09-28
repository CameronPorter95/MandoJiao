import CoreDomain
import Foundation
import VocabularyDomain

nonisolated struct DictionaryRepositoryImpl: DictionaryRepository {
    func entries(forHanzi hanzi: String) async throws -> [DictionaryEntry] {
        do {
            return try await BundledDictionary.shared.index().entries(forHanzi: hanzi)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VocabularyDomainError.unexpected(model: DomainErrorModel(error))
        }
    }

    func search(_ query: String, limit: Int) async throws -> [DictionarySearchResult] {
        do {
            let search = try await BundledDictionary.shared.search()
            try Task.checkCancellation()
            return search.results(for: query, limit: limit)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VocabularyDomainError.unexpected(model: DomainErrorModel(error))
        }
    }
}

/// The bundled CC-CEDICT, read from disk once and shared with the lexicon.
public nonisolated enum CEDICT {
    public static let dictionary: any DictionaryRepository = DictionaryRepositoryImpl()
}
