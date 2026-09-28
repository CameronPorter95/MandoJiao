import Foundation

// Builds the HSK word list the built-in HSK decks are made from.
//
// Download complete.json from https://github.com/drkameleon/complete-hsk-vocabulary, then
// run from the repository root, after MakeDictionary:
//   swift Tools/MakeHSK/main.swift complete.json Vocabulary/Sources/VocabularyData/Resources/Dictionary.tsv Tools/MakeHSK/headlines.tsv Vocabulary/Sources/VocabularyData/Resources/HSK.tsv
//
// Output is one line per word of the 2025 revision of HSK 3.0 ("newest" in the source):
// level, frequency rank, Hanzi, pinyin, then meanings joined by U+001F, tab separated,
// levels 7 to 9 as level 7.
//
// Pinyin and meanings come from the bundled dictionary, so an HSK word reads as one whose
// senses were chosen in the word editor: senses as the dictionary writes them, asides and
// all, the first being the headline. The source lists every reading of a character, not the
// one the syllabus means, so of the dictionary's readings that the source also gives, the
// dictionary's preferred one is taken, and failing that the one with the most senses. At
// most `meaningLimit` senses are kept: 打 has more than twenty, which no reveal could show.
// A word with no such reading keeps the source's pinyin and meanings.
//
// headlines.tsv overrides that for HSK 1 to 3, where the dictionary's first sense is not
// what a learner means by the word: 在 heads with "at, in", not "to exist". See its header.
//
// Words are in standard Mandarin, not Beijing erhua: 一点儿 becomes 一点. Where dropping the
// 儿 changes the meaning, the standard word is used instead (哪儿 is 哪里, not 哪), and an
// erhua word whose standard form is already in the syllabus is left out as a duplicate.

struct Source: Decodable {
    struct Form: Decodable {
        struct Transcriptions: Decodable {
            let pinyin: String
            let numeric: String
        }
        let transcriptions: Transcriptions
        let meanings: [String]
    }

    let simplified: String
    let level: [String]
    let frequency: Int
    let forms: [Form]
}

let arguments = CommandLine.arguments
guard arguments.count == 5 else {
    FileHandle.standardError.write(Data("usage: main.swift <complete.json> <Dictionary.tsv> <headlines.tsv> <HSK.tsv>\n".utf8))
    exit(1)
}

let meaningLimit = 4
let separator = "\u{1F}"

let entries = try JSONDecoder().decode([Source].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))

struct Reading {
    let pinyin: String
    let isPreferred: Bool
    let senses: [String]
}

/// Every reading, those with no senses too: 呀's `ya` has none, since its only sense points
/// at 啊, and knowing it is there keeps 呀 from taking `yā`, "ah", instead.
var dictionary: [String: [Reading]] = [:]
for line in try String(contentsOfFile: arguments[2], encoding: .utf8).split(separator: "\n") where !line.hasPrefix("#") {
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard fields.count == 5 else { continue }
    dictionary[fields[0], default: []].append(Reading(
        pinyin: fields[2],
        isPreferred: fields[3] == "1",
        senses: fields[4].isEmpty ? [] : fields[4].components(separatedBy: separator)
    ))
}

/// Hanzi to a reading, blank to keep HSK's, and the headline to put first.
var headlines: [String: (pinyin: String, headline: String)] = [:]
for line in try String(contentsOfFile: arguments[3], encoding: .utf8).split(separator: "\n") where !line.hasPrefix("#") {
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard fields.count == 3, !fields[2].isEmpty else {
        FileHandle.standardError.write(Data("headlines.tsv: bad line \(line)\n".utf8))
        exit(1)
    }
    headlines[fields[0]] = (fields[1], fields[2])
}
var unusedHeadlines = Set(headlines.keys)

/// The chosen headline first, then the reading's other senses. A reading given in
/// headlines.tsv takes that reading's senses instead.
func withHeadline(_ hanzi: String, _ pinyin: String, _ senses: [String]) -> (pinyin: String, meanings: [String]) {
    guard let chosen = headlines[hanzi] else { return (pinyin, senses) }
    unusedHeadlines.remove(hanzi)
    var (pinyin, senses) = (pinyin, senses)
    if !chosen.pinyin.isEmpty {
        guard let reading = dictionary[hanzi]?.first(where: { comparable($0.pinyin) == comparable(chosen.pinyin) && !$0.senses.isEmpty }) else {
            FileHandle.standardError.write(Data("headlines.tsv: \(hanzi) has no reading \(chosen.pinyin)\n".utf8))
            exit(1)
        }
        (pinyin, senses) = (reading.pinyin, reading.senses)
    }
    // Another line of the same reading may have it: 周 zhōu is "to make a circuit" on one
    // and "week" on another.
    if !senses.contains(chosen.headline),
       let line = dictionary[hanzi]?.first(where: { comparable($0.pinyin) == comparable(pinyin) && $0.senses.contains(chosen.headline) }) {
        senses = line.senses
    }
    // Nor a sense the headline already says: 种's "kind, type" makes a later "kind" redundant.
    let parts = Set(chosen.headline.components(separatedBy: ", "))
    return (pinyin, [chosen.headline] + senses.filter { $0 != chosen.headline && !parts.contains($0) })
}

/// Of the dictionary's readings with senses that the source also gives, its preferred one,
/// else the fullest. Failing any, the same ignoring tones, and failing that the dictionary's
/// only reading with senses: 泄露 is `xièlù` in the source and `xièlòu` in the dictionary,
/// the mainland standard, which the source lists as "also pr.". Nil when the source's exact
/// reading is in the dictionary without senses, so the source's reading stands.
func reading(_ hanzi: String, among forms: [Source.Form]) -> Reading? {
    let readings = dictionary[hanzi] ?? []
    let withSenses = readings.filter { !$0.senses.isEmpty }
    func best(by key: (String) -> String) -> Reading? {
        let given = Set(forms.map { key($0.transcriptions.pinyin) })
        let matching = withSenses.filter { given.contains(key($0.pinyin)) }
        return matching.first(where: \.isPreferred) ?? matching.max { $0.senses.count < $1.senses.count }
    }
    if let exact = best(by: comparable) { return exact }
    let given = Set(forms.map { comparable($0.transcriptions.pinyin) })
    if readings.contains(where: { given.contains(comparable($0.pinyin)) }) { return nil }
    return best(by: toneless) ?? (withSenses.count == 1 ? withSenses[0] : nil)
}

/// The source's own meanings, for the few words the dictionary cannot give, cleaned as the
/// dictionary's are: 大厦's only sense names its example buildings in Hanzi, and 泄露's
/// ends "also pr. [xiè lòu]".
func cleaned(_ meanings: [String]) -> [String] {
    meanings.compactMap { meaning in
        guard !meaning.hasPrefix("also pr.") else { return nil }
        let text = meaning
            .replacingOccurrences(of: "[\\p{Han}|]+(\\[[^\\]]*\\])?", with: "", options: .regularExpression)
            .replacingOccurrences(of: "; ", with: ", ")
            .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            .replacingOccurrences(of: " )", with: ")")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;."))
        return text.isEmpty ? nil : text
    }
}

func line(_ level: Int, _ rank: Int, _ hanzi: String, _ pinyin: String, _ meanings: [String]) -> String {
    "\(level)\t\(rank)\t\(hanzi)\t\(pinyin)\t\(meanings.prefix(meaningLimit).joined(separator: separator))"
}

/// Tone marks kept, spaces and case dropped, so `yín háng` and `yínháng` compare equal.
/// The source writes ü as `u:` in some words, 略 `lu:è` for the dictionary's `lüè`, and
/// marks some neutral tones with a dot, 闺女 `guī˙nu:`.
func comparable(_ pinyin: String) -> String {
    pinyin.replacingOccurrences(of: "u:", with: "ü").precomposedStringWithCanonicalMapping
        .lowercased().filter { !$0.isWhitespace && $0 != "'" && $0 != "˙" }
}

/// For a source reading whose tone marks are wrong, like 欧洲 `Oū zhōu`.
func toneless(_ pinyin: String) -> String {
    comparable(pinyin).folding(options: .diacriticInsensitive, locale: nil)
}

/// Where the erhua word's standard form is a different word, not the same one without 儿.
let standardForms = ["哪儿": "哪里", "这儿": "这里", "那儿": "那里", "一块儿": "一起"]

/// The source ends an erhua reading in a neutral r, as `r5` or glued on as `fǎr5`. A real
/// 儿, as in 儿子, is `er2` and is kept.
func isErhua(_ entry: Source) -> Bool {
    entry.simplified.hasSuffix("儿") && entry.forms.contains {
        $0.transcriptions.numeric.lowercased().hasSuffix("r5")
    }
}

let syllabus = Set(entries.filter { $0.level.contains { $0.hasPrefix("newest-") } }.map(\.simplified))

var lines: [(level: Int, rank: Int, line: String)] = []
var standardised: [String] = []
var ambiguous = 0
var unknown: [String] = []
for entry in entries {
    let levels = entry.level.compactMap { $0.hasPrefix("newest-") ? Int($0.dropFirst("newest-".count)) : nil }
    guard let level = levels.min() else { continue }

    if isErhua(entry) {
        let standard = standardForms[entry.simplified] ?? String(entry.simplified.dropLast())
        // The standard word's readings are not the erhua word's, so the dictionary's
        // preferred one stands.
        guard !syllabus.contains(standard),
              let known = dictionary[standard]?.first(where: \.isPreferred) ?? dictionary[standard]?.first
        else {
            standardised.append("\(entry.simplified) dropped")
            continue
        }
        standardised.append("\(entry.simplified) → \(standard)")
        lines.append((level, entry.frequency, line(level, entry.frequency, standard, known.pinyin, known.senses)))
        continue
    }

    // A surname reading is never the syllabus word unless it is the only one.
    let forms = entry.forms.count == 1 ? entry.forms : entry.forms.filter { !($0.transcriptions.pinyin.first?.isUppercase ?? false) }
    if Set(forms.map { comparable($0.transcriptions.pinyin) }).count > 1 { ambiguous += 1 }

    if let known = reading(entry.simplified, among: forms) {
        let chosen = withHeadline(entry.simplified, known.pinyin, known.senses)
        lines.append((level, entry.frequency, line(level, entry.frequency, entry.simplified, chosen.pinyin, chosen.meanings)))
    } else {
        unknown.append(entry.simplified)
        let pinyin = forms.first.map { $0.transcriptions.pinyin.replacingOccurrences(of: " ", with: "") } ?? ""
        lines.append((level, entry.frequency, line(level, entry.frequency, entry.simplified, pinyin, cleaned(forms.first?.meanings ?? []))))
    }
}

lines.sort { ($0.level, $0.rank) < ($1.level, $1.rank) }
let header = "# HSK 3.0, 2025 revision, from complete-hsk-vocabulary (MIT, Yanis Zafirópulos)"
try ([header] + lines.map(\.line)).joined(separator: "\n").appending("\n")
    .write(toFile: arguments[4], atomically: true, encoding: .utf8)

let counts = Dictionary(grouping: lines, by: \.level).mapValues(\.count).sorted { $0.key < $1.key }
print("words by level:", counts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
print("\(ambiguous) with several readings, \(unknown.count) not in the dictionary or read differently there:", unknown.prefix(30).joined(separator: " "))
print("erhua made standard:", standardised.joined(separator: ", "))
print("\(headlines.count - unusedHeadlines.count) headlines chosen by hand")
if !unusedHeadlines.isEmpty {
    FileHandle.standardError.write(Data("headlines.tsv: not HSK words: \(unusedHeadlines.sorted().joined(separator: " "))\n".utf8))
    exit(1)
}
