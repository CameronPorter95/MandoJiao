import CoreDomain
import DictionaryDomain
import Foundation

/// Reads `Examples.tsv`, which `Tools/MakeExamples` builds from Tatoeba, once for the app's
/// lifetime.
actor ExampleRepositoryImpl: ExampleRepository {
    private var loaded: BundledExamples.Table?

    func examples(forHanzi hanzi: String, pinyin: String) throws -> [ExampleSentence] {
        guard let readings = try table()[hanzi] else { return [] }
        guard !pinyin.isEmpty else { return readings.first?.sentences ?? [] }
        return readings.first { DictionaryEntry.spellSame($0.pinyin, pinyin) }?.sentences ?? []
    }

    private func table() throws -> BundledExamples.Table {
        if let loaded { return loaded }
        do {
            let table = try BundledExamples.table()
            loaded = table
            return table
        } catch {
            throw DictionaryDomainError.unexpected(model: DomainErrorModel(error))
        }
    }
}

nonisolated enum BundledExamples {
    /// Each headword's readings in the file's order, with their sentences best first.
    typealias Table = [String: [(pinyin: String, sentences: [ExampleSentence])]]

    enum Failure: Error {
        case missingResource
    }

    static func table() throws -> Table {
        guard let url = Bundle.module.url(forResource: "Examples", withExtension: "tsv") else {
            throw Failure.missingResource
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }

    /// `S` lines are sentences by id, `W` lines a reading's sentence ids, best first.
    static func parse(_ text: String) -> Table {
        var sentences: [Substring: ExampleSentence] = [:]
        var table: Table = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            switch fields.first {
            case "S" where fields.count == 5:
                sentences[fields[1]] = ExampleSentence(hanzi: String(fields[2]), pinyin: String(fields[3]), english: String(fields[4]))
            case "W" where fields.count == 4:
                let found = fields[3].split(separator: ",").compactMap { sentences[$0] }
                table[String(fields[1]), default: []].append((String(fields[2]), found))
            default:
                continue
            }
        }
        return table
    }
}

/// The one example repository, so the file is read once however many screens ask.
public nonisolated enum Tatoeba {
    public static let examples: any ExampleRepository = ExampleRepositoryImpl()
}
