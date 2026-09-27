import Foundation

// Builds the HSK word list the built-in HSK decks are made from.
//
// Download complete.json from https://github.com/drkameleon/complete-hsk-vocabulary, then
// run from the repository root, after MakeLexicon:
//   swift Tools/MakeHSK/main.swift complete.json Vocabulary/Sources/VocabularyData/Resources/Lexicon.tsv Vocabulary/Sources/VocabularyData/Resources/HSK.tsv
//
// Output is one line per word of the 2025 revision of HSK 3.0 ("newest" in the source):
// level, frequency rank, Hanzi, pinyin, English, tab separated, levels 7 to 9 as level 7.
// Pinyin and English come from the lexicon when it knows the word, so they read as the word
// editor's suggestions do. The source lists every reading of a character, not the one the
// syllabus means, so the lexicon's reading picks among them.
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
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: main.swift <complete.json> <Lexicon.tsv> <HSK.tsv>\n".utf8))
    exit(1)
}

let entries = try JSONDecoder().decode([Source].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))

var lexicon: [String: (pinyin: String, english: String)] = [:]
for line in try String(contentsOfFile: arguments[2], encoding: .utf8).split(separator: "\n") where !line.hasPrefix("#") {
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    if fields.count == 3 { lexicon[fields[0]] = (fields[1], fields[2]) }
}

/// Tone marks kept, spaces and case dropped, so `yín háng` and `yínháng` compare equal.
func comparable(_ pinyin: String) -> String {
    pinyin.lowercased().filter { !$0.isWhitespace && $0 != "'" }
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
        guard !syllabus.contains(standard), let known = lexicon[standard] else {
            standardised.append("\(entry.simplified) dropped")
            continue
        }
        standardised.append("\(entry.simplified) → \(standard)")
        lines.append((level, entry.frequency, "\(level)\t\(entry.frequency)\t\(standard)\t\(known.pinyin)\t\(known.english)"))
        continue
    }

    // A surname reading is never the syllabus word unless it is the only one.
    let forms = entry.forms.count == 1 ? entry.forms : entry.forms.filter { !($0.transcriptions.pinyin.first?.isUppercase ?? false) }
    if Set(forms.map { comparable($0.transcriptions.pinyin) }).count > 1 { ambiguous += 1 }

    let pinyin: String
    let english: String
    if let known = lexicon[entry.simplified], forms.contains(where: { comparable($0.transcriptions.pinyin) == comparable(known.pinyin) }) {
        pinyin = known.pinyin
        english = known.english.isEmpty ? forms.first?.meanings.first ?? "" : known.english
    } else {
        unknown.append(entry.simplified)
        pinyin = forms.first.map { $0.transcriptions.pinyin.replacingOccurrences(of: " ", with: "") } ?? ""
        english = forms.first?.meanings.first ?? ""
    }
    lines.append((level, entry.frequency, "\(level)\t\(entry.frequency)\t\(entry.simplified)\t\(pinyin)\t\(english)"))
}

lines.sort { ($0.level, $0.rank) < ($1.level, $1.rank) }
let header = "# HSK 3.0, 2025 revision, from complete-hsk-vocabulary (MIT, Yanis Zafirópulos)"
try ([header] + lines.map(\.line)).joined(separator: "\n").appending("\n")
    .write(toFile: arguments[3], atomically: true, encoding: .utf8)

let counts = Dictionary(grouping: lines, by: \.level).mapValues(\.count).sorted { $0.key < $1.key }
print("words by level:", counts.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
print("\(ambiguous) with several readings, \(unknown.count) not in the lexicon or read differently there")
print("erhua made standard:", standardised.joined(separator: ", "))
