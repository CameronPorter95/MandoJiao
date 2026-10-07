import CoreDomain
import DictionaryDomain
import Foundation

nonisolated struct DictionaryRepositoryImpl: DictionaryRepository {
    func entries(forHanzi hanzi: String) async throws -> [DictionaryEntry] {
        do {
            // CC-CEDICT with HSK's headlines put first, so a headword reads as its library word.
            return HSKHeadlines.bundled.applied(to: try await BundledDictionary.shared.index().entries(forHanzi: hanzi))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DictionaryDomainError.unexpected(model: DomainErrorModel(error))
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
            throw DictionaryDomainError.unexpected(model: DomainErrorModel(error))
        }
    }
}

/// The bundled CC-CEDICT, read from disk once and shared with the lexicon.
public nonisolated enum CEDICT {
    public static let dictionary: any DictionaryRepository = DictionaryRepositoryImpl()
}
