import CoreDomain
import Foundation
import VocabularyDomain

/// Reads `HSK.tsv`, which `Tools/MakeHSK` builds, once for the app's lifetime.
actor HSKRepositoryImpl: HSKRepository {
    private var loaded: [HSKWord]?

    func words() throws -> [HSKWord] {
        if let loaded { return loaded }
        do {
            let words = try BundledHSK.words()
            loaded = words
            return words
        } catch {
            throw VocabularyDomainError.unexpected(model: DomainErrorModel(error))
        }
    }
}

nonisolated enum BundledHSK {
    enum Failure: Error {
        case missingResource
    }

    /// Synchronous, so seeding a fresh store can read it too.
    static func words() throws -> [HSKWord] {
        guard let url = Bundle.module.url(forResource: "HSK", withExtension: "tsv") else {
            throw Failure.missingResource
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }

    static func parse(_ text: String) -> [HSKWord] {
        text.split(separator: "\n").compactMap { line in
            guard !line.hasPrefix("#") else { return nil }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 5, let level = Int(fields[0]), let rank = Int(fields[1]) else { return nil }
            return HSKWord(level: level, rank: rank, hanzi: fields[2], pinyin: fields[3], english: fields[4])
        }
    }
}

/// The one HSK repository, so the file is read once however many screens ask.
public nonisolated enum HSKSource {
    public static let repository: any HSKRepository = HSKRepositoryImpl()
}
