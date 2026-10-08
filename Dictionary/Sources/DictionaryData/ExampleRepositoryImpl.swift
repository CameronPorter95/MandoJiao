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
            case "S" where fields.count == 6:
                let hanzi = String(fields[2])
                sentences[fields[1]] = ExampleSentence(
                    hanzi: hanzi, pinyin: String(fields[3]), english: String(fields[4]),
                    words: words(of: hanzi, lengths: fields[5])
                )
            case "W" where fields.count == 4:
                let found = fields[3].split(separator: ",").compactMap { sentences[$0] }
                table[String(fields[1]), default: []].append((String(fields[2]), found))
            default:
                continue
            }
        }
        return table
    }

    /// The sentence's Han characters cut at each length: "2,1,1,2" of 学生是我朋友。 is
    /// 学生 是 我 朋友. Empty when the lengths do not add up to the characters.
    static func words(of hanzi: String, lengths: Substring) -> [String] {
        let characters = hanzi.filter { $0.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x2FFFF).contains($0.value) } }.map(String.init)
        let sizes = lengths.split(separator: ",").compactMap { Int($0) }
        guard sizes.reduce(0, +) == characters.count else { return [] }
        var words: [String] = []
        var start = 0
        for size in sizes {
            words.append(characters[start..<start + size].joined())
            start += size
        }
        return words
    }
}

/// The one example repository, so the file is read once however many screens ask.
public nonisolated enum Tatoeba {
    public static let examples: any ExampleRepository = ExampleRepositoryImpl()
}
