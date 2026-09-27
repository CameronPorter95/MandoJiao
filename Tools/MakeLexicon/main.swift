import Foundation

// Builds the lexicon the word editor suggests pinyin and English from.
//
// Download CC-CEDICT from https://www.mdbg.net/chinese/dictionary?page=cc-cedict, then
// run from the repository root:
//   swift Tools/MakeLexicon/main.swift cedict_ts.u8 Vocabulary/Sources/VocabularyData/Resources/Lexicon.tsv
//
// Output is one line per simplified headword: hanzi, pinyin with tone marks, and one
// short English gloss, tab separated. CC-CEDICT is CC BY-SA 4.0, so the output is too,
// and its header line carries the attribution.

struct Entry {
    let simplified: String
    let pinyin: String
    let glosses: [String]
    let order: Int

    var isProperNoun: Bool { pinyin.first?.isUppercase ?? false }
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: main.swift <cedict_ts.u8> <Lexicon.tsv>\n".utf8))
    exit(1)
}

let source = try String(contentsOfFile: arguments[1], encoding: .utf8)
var date = "unknown date"
var entries: [Entry] = []

for (index, line) in source.split(whereSeparator: \.isNewline).enumerated() {
    if line.hasPrefix("#! date=") {
        date = String(line.dropFirst("#! date=".count).prefix(10))
    }
    guard !line.hasPrefix("#") else { continue }
    // 傳統 传统 [chuan2 tong3] /tradition/traditional/
    guard let open = line.firstIndex(of: "["), let close = line.firstIndex(of: "]") else { continue }
    let headwords = line[..<open].split(separator: " ")
    guard headwords.count == 2 else { continue }
    let glosses = line[line.index(after: close)...]
        .split(separator: "/")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    entries.append(Entry(
        simplified: String(headwords[1]),
        pinyin: String(line[line.index(after: open)..<close]),
        glosses: glosses,
        order: index
    ))
}

// MARK: Glosses

func isHan(_ scalar: Unicode.Scalar) -> Bool {
    (0x3400...0x9FFF).contains(scalar.value) || (0x20000...0x2FFFF).contains(scalar.value)
}

/// Removes every parenthesised aside, including nested ones.
func strippingAsides(_ text: String) -> String {
    var depth = 0
    var kept = ""
    for character in text {
        switch character {
        case "(": depth += 1
        case ")": depth = max(0, depth - 1)
        default: if depth == 0 { kept.append(character) }
        }
    }
    return kept
}

let referencePrefixes = [
    "surname ", "variant of", "old variant of", "archaic variant of", "unofficial variant of",
    "Japanese variant of", "erhua variant of", "used in ", "see ", "CL:", "abbr. for", "abbr. of",
    "also written", "also pr.", "Taiwan pr.", "classifier for",
]

/// Removes inline references like `陝西省|陕西省[Shan3 xi1 Sheng3]`.
func strippingReferences(_ text: String) -> String {
    text.replacingOccurrences(
        of: "[\\p{Han}|]+(\\[[^\\]]*\\])?",
        with: "",
        options: .regularExpression
    )
}

/// Long glosses are cut back to their leading senses, then to whole words.
func shortened(_ text: String, limit: Int = 40) -> String {
    guard text.count > limit else { return text }
    let first = text.components(separatedBy: " – ")[0]
    var kept: [Substring] = []
    for sense in first.split(separator: ", ") {
        if !kept.isEmpty, (kept + [sense]).joined(separator: ", ").count > limit { break }
        kept.append(sense)
    }
    let joined = kept.joined(separator: ", ")
    guard joined.count > limit else { return joined }
    var words: [Substring] = []
    for word in joined.split(separator: " ") {
        if !words.isEmpty, (words + [word]).joined(separator: " ").count > limit { break }
        words.append(word)
    }
    return words.joined(separator: " ")
}

/// The headword a cross reference like `see 西安市[Xi1 an1 Shi4]` points at.
func referencedHeadword(_ gloss: String) -> String? {
    let prefixes = ["see ", "variant of ", "erhua variant of ", "old variant of ", "also written "]
    guard prefixes.contains(where: gloss.hasPrefix),
          let match = gloss.range(of: "[\\p{Han}|]+(?=\\[)", options: .regularExpression)
    else { return nil }
    return gloss[match].split(separator: "|").last.map(String.init)
}

/// A gloss worth showing as a suggestion, or nil for a cross reference or a surname.
func usableGloss(_ raw: String) -> String? {
    if referencePrefixes.contains(where: raw.hasPrefix) { return nil }
    var text = strippingReferences(strippingAsides(raw))
    if text.trimmingCharacters(in: .whitespaces).isEmpty {
        // A gloss that is only an aside, like 了's "(completed action marker)", is the meaning.
        text = String(raw.dropFirst().dropLast())
    }
    text = text
        .replacingOccurrences(of: "\\s+([,;])", with: "$1", options: .regularExpression)
        .replacingOccurrences(of: "; ", with: ", ")
        .split(separator: " ", omittingEmptySubsequences: true)
        .joined(separator: " ")
        .trimmingCharacters(in: CharacterSet(charactersIn: " ,;."))
    if text.isEmpty || text.contains("[") || text.unicodeScalars.contains(where: isHan) { return nil }
    if referencePrefixes.contains(where: text.hasPrefix) { return nil }
    return shortened(text)
}

// MARK: Pinyin

let toneMarks: [Character: [Character]] = [
    "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"], "i": ["ī", "í", "ǐ", "ì"],
    "o": ["ō", "ó", "ǒ", "ò"], "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
    "A": ["Ā", "Á", "Ǎ", "À"], "E": ["Ē", "É", "Ě", "È"], "O": ["Ō", "Ó", "Ǒ", "Ò"],
]

/// `lu:4` to `lǜ`. The mark goes on a or e, else the o of ou, else the last vowel.
func marked(_ syllable: Substring) -> (text: String, isSyllable: Bool) {
    var letters = String(syllable)
        .replacingOccurrences(of: "u:", with: "ü")
        .replacingOccurrences(of: "U:", with: "Ü")
    guard let digit = letters.last?.wholeNumberValue, (1...5).contains(digit) else {
        return (letters, false)
    }
    letters.removeLast()
    guard digit < 5 else { return (letters, true) }

    let characters = Array(letters)
    let lowered = letters.lowercased()
    let target: Int?
    if let a = characters.firstIndex(where: { "aAeE".contains($0) }) {
        target = a
    } else if let range = lowered.range(of: "ou") {
        target = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
    } else {
        target = characters.lastIndex(where: { "iouüIOUÜ".contains($0) })
    }
    guard let target, let marks = toneMarks[characters[target]] else { return (letters, true) }
    var result = characters
    result[target] = marks[digit - 1]
    return (String(result), true)
}

/// Syllables joined into one word, with an apostrophe where a syllable starts with a vowel.
func displayPinyin(_ numbered: String) -> String {
    var output = ""
    var previousWasSyllable = false
    for token in numbered.split(separator: " ") {
        let (text, isSyllable) = marked(token)
        if isSyllable && previousWasSyllable, let first = text.lowercased().first, "aāáǎàeēéěèoōóǒò".contains(first) {
            output.append("'")
        } else if !isSyllable && token != "," && token != "·" && !output.isEmpty {
            output.append(" ")
        }
        output.append(text == "," || text == "·" ? " " : text)
        previousWasSyllable = isSyllable
    }
    return output.split(separator: " ").joined(separator: " ")
}

// MARK: Choosing one entry per headword

// CC-CEDICT orders readings alphabetically. The system transform picks the everyday one.
func systemReading(_ character: String) -> String {
    let text = NSMutableString(string: character)
    CFStringTransform(text, nil, kCFStringTransformMandarinLatin, false)
    return text as String
}

var compoundReadings: [String: Int] = [:]
for entry in entries where entry.simplified.count > 1 && !entry.isProperNoun {
    let syllables = entry.pinyin.lowercased().split(separator: " ")
    guard syllables.count == entry.simplified.count else { continue }
    for (character, syllable) in zip(entry.simplified, syllables) {
        compoundReadings["\(character) \(syllable.dropLast())", default: 0] += 1
    }
}

func compoundScore(_ entry: Entry) -> Int {
    guard entry.simplified.count == 1 else { return 0 }
    let toneless = entry.pinyin.lowercased().dropLast()
    return compoundReadings["\(entry.simplified) \(toneless)", default: 0]
}

func rank(_ candidates: [Entry]) -> Entry {
    let system = candidates[0].simplified.count == 1 ? systemReading(candidates[0].simplified) : nil
    return candidates.min { a, b in
        let aGlosses = a.glosses.compactMap(usableGloss).count
        let bGlosses = b.glosses.compactMap(usableGloss).count
        if (aGlosses > 0) != (bGlosses > 0) { return aGlosses > 0 }
        if a.isProperNoun != b.isProperNoun { return !a.isProperNoun }
        if let system {
            let (aMatches, bMatches) = (displayPinyin(a.pinyin) == system, displayPinyin(b.pinyin) == system)
            if aMatches != bMatches { return aMatches }
        }
        let (aScore, bScore) = (compoundScore(a), compoundScore(b))
        if aScore != bScore { return aScore > bScore }
        if aGlosses != bGlosses { return aGlosses > bGlosses }
        return a.order < b.order
    }!
}

let chosen = Dictionary(grouping: entries, by: \.simplified).mapValues(rank)
let english = chosen.mapValues { $0.glosses.lazy.compactMap(usableGloss).first ?? "" }

var lines = ["# CC-CEDICT \(date), CC BY-SA 4.0, https://cc-cedict.org"]
for simplified in chosen.keys.sorted() {
    let entry = chosen[simplified]!
    var gloss = english[simplified]!
    if gloss.isEmpty {
        gloss = entry.glosses.lazy.compactMap(referencedHeadword).compactMap { english[$0] }.first { !$0.isEmpty } ?? ""
    }
    lines.append("\(simplified)\t\(displayPinyin(entry.pinyin))\t\(gloss)")
}
try (lines.joined(separator: "\n") + "\n").write(toFile: arguments[2], atomically: true, encoding: .utf8)
print("\(lines.count - 1) headwords from \(entries.count) entries")
