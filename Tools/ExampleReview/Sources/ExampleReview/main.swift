import DictionaryDI
import DictionaryDomain
import Foundation
import LibraryDomain

// Runs the app's own example writer, the on-device model behind GenerateExampleUseCase, over
// every word Today's plan would ask it for: a starter or HSK 1-3 word whose card meaning no
// Tatoeba sentence says. Needs a Mac with Apple Intelligence on. Run from this folder:
//   swift run review-examples [--runs 3] [--known starter|none] [--out ExampleReview.json]
//
// The learner is taken to know the starter words, as a learner a few days in does, so the
// prompt asks the model to keep to them. Each word is written `--runs` times, each run with
// the use case's own retries, and every attempt's answer is counted. The JSON is what the
// review page shows a native speaker.

struct Word: Codable {
    let source: String
    let hanzi: String
    let pinyin: String
    let meaning: String
}

struct Run: Codable {
    let word: Word
    let run: Int
    /// "kept", "none" (every attempt refused or unfit), "error" (the app would log it and show
    /// no example) or "unavailable".
    let outcome: String
    let attempts: Int
    let refused: Int
    let unfit: Int
    let hanzi: String?
    let pinyin: String?
    let english: String?
    let seconds: Double
    /// Every unfit sentence, so the review can see what was dropped.
    let dropped: [String]
}

/// Passes each attempt to the app's generator and keeps its answer for the report.
actor CountingGenerator: ExampleGenerating {
    private let generator: any ExampleGenerating
    private(set) var answers: [ExampleWriting] = []

    init(_ generator: any ExampleGenerating) {
        self.generator = generator
    }

    func example(for request: ExampleRequest) async throws -> ExampleWriting {
        let answer = try await generator.example(for: request)
        answers.append(answer)
        return answer
    }

    func reset() {
        answers = []
    }
}

func option(_ name: String, default value: String) -> String {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return value }
    return arguments[index + 1]
}

let runs = Int(option("--runs", default: "3")) ?? 3
let output = URL(fileURLWithPath: option("--out", default: "ExampleReview.json"))

// MARK: The words that would ask for a sentence

var words: [Word] = SampleVocabulary.allEntries.map {
    Word(source: "starter", hanzi: $0.hanzi, pinyin: $0.pinyin, meaning: $0.english)
}
var seen = Set<String>()
for word in try DictionaryRepositoryFactory.bundledHSKWords() where word.level <= 3 && !seen.contains(word.hanzi + word.pinyin) {
    seen.insert(word.hanzi + word.pinyin)
    // A starter word keeps its own card, as installing HSK does.
    guard !words.contains(where: { $0.hanzi == word.hanzi }), let headline = word.meanings.first else { continue }
    words.append(Word(source: "HSK \(word.level)", hanzi: word.hanzi, pinyin: word.pinyin, meaning: headline))
}

let findExamples = FindExamplesUseCase(repository: DictionaryRepositoryFactory.makeExampleRepository())
var asking: [Word] = []
for word in words where EnglishMeaning.isCheckable(word.meaning) {
    let sentences = try await findExamples(hanzi: word.hanzi, pinyin: word.pinyin)
    if sentences.best(teaching: word.hanzi, meanings: [word.meaning], knowing: []) == nil {
        asking.append(word)
    }
}
print("\(asking.count) of \(words.count) starter and HSK 1-3 words would ask the model for a sentence")

// MARK: Writing

// "none" asks for sentences with no word list, to see whether keeping to one costs quality:
// with the starter's words, the first run leant on 买书 and 今天 in sentence after sentence.
let known: Set<String> = option("--known", default: "starter") == "none" ? [] : Set(SampleVocabulary.allEntries.map(\.hanzi))
let generator = CountingGenerator(DictionaryRepositoryFactory.makeExampleGenerator())
let generate = GenerateExampleUseCase(generator: generator)
var results: [Run] = []

for word in asking {
    for run in 1...runs {
        await generator.reset()
        let request = ExampleRequest(hanzi: word.hanzi, pinyin: word.pinyin, meaning: word.meaning, known: known)
        let started = ContinuousClock.now
        let sentence: ExampleSentence?
        do {
            sentence = try await generate(request)
        } catch {
            // The app logs these and shows no example; the review counts them and carries on.
            print("\(word.hanzi) \(run): error \(error)")
            results.append(Run(
                word: word, run: run, outcome: "error", attempts: await generator.answers.count + 1,
                refused: 0, unfit: 0, hanzi: nil, pinyin: nil, english: nil, seconds: 0, dropped: ["\(error)"]
            ))
            continue
        }
        let elapsed = (ContinuousClock.now - started).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        let answers = await generator.answers
        let dropped = answers.compactMap { answer -> String? in
            guard case .written(let written) = answer, !GenerateExampleUseCase.isFit(written, for: request) else { return nil }
            return "\(written.hanzi) | \(written.english)"
        }
        let outcome = sentence != nil ? "kept" : answers.contains(.unavailable) ? "unavailable" : "none"
        results.append(Run(
            word: word, run: run, outcome: outcome, attempts: answers.count,
            refused: answers.count { $0 == .refused }, unfit: dropped.count,
            hanzi: sentence?.hanzi, pinyin: sentence?.pinyin, english: sentence?.english,
            seconds: seconds, dropped: dropped
        ))
        print("\(word.hanzi) \(run): \(outcome) after \(answers.count)  \(sentence.map { "\($0.hanzi) | \($0.english)" } ?? dropped.joined(separator: "; "))")
        if outcome == "unavailable" {
            print("The model is unavailable on this Mac: Apple Intelligence must be on.")
            exit(1)
        }
    }
}

// MARK: Report

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let round = ISO8601DateFormatter.string(from: .now, timeZone: .current, formatOptions: [.withFullDate, .withTime, .withColonSeparatorInTime])
    .replacingOccurrences(of: ":", with: "")
struct Report: Encodable {
    let round: String
    /// "starter" or "none": the words the model was asked to keep to.
    let known: String
    let runs: [Run]
}
try encoder.encode(Report(round: round, known: known.isEmpty ? "none" : "starter", runs: results)).write(to: output)

let kept = results.count { $0.outcome == "kept" }
let attempts = results.map(\.attempts).reduce(0, +)
let wordsKept = Set(results.filter { $0.outcome == "kept" }.map { $0.word.hanzi + $0.word.pinyin }).count
print("""

    \(asking.count) words, \(results.count) runs: \(kept) kept (\(results.isEmpty ? 0 : 100 * kept / results.count)%), \
    \(wordsKept) words with at least one.
    \(attempts) attempts: \(results.map(\.refused).reduce(0, +)) refused, \(results.map(\.unfit).reduce(0, +)) unfit.
    \(String(format: "%.1f", results.map(\.seconds).reduce(0, +) / Double(max(results.count, 1))))s a run on average.
    Written to \(output.path).
    """)
