import Foundation

// Builds the dictionary: every CC-CEDICT entry with all its senses. The word editor's
// suggestions are read from it too, from each headword's preferred entry.
//
// Download CC-CEDICT from https://www.mdbg.net/chinese/dictionary?page=cc-cedict, then
// run from the repository root:
//   swift Tools/MakeDictionary/main.swift cedict_ts.u8 Vocabulary/Sources/VocabularyData/Resources/Dictionary.tsv
//
// One line per entry: simplified, traditional, pinyin with tone marks, 1 if it is the
// headword's preferred entry, and its senses, tab separated, senses split by U+001F.
// CC-CEDICT is CC BY-SA 4.0, so the output is too, and its header line carries the
// attribution.

struct Entry {
    let simplified: String
    let traditional: String
    let pinyin: String
    let glosses: [String]
    let order: Int

    var isProperNoun: Bool { pinyin.first?.isUppercase ?? false }
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: main.swift <cedict_ts.u8> <Dictionary.tsv>\n".utf8))
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
        traditional: String(headwords[0]),
        pinyin: String(line[line.index(after: open)..<close]),
        glosses: glosses,
        order: index
    ))
}

// MARK: Glosses

func isHan(_ scalar: Unicode.Scalar) -> Bool {
    (0x3400...0x9FFF).contains(scalar.value) || (0x20000...0x2FFFF).contains(scalar.value)
}

/// Removes the top-level parenthesised asides that `matching` picks, nested ones included.
func strippingAsides(_ text: String, containing matching: (String) -> Bool) -> String {
    var depth = 0
    var kept = ""
    var aside = ""
    for character in text {
        switch character {
        case "(":
            depth += 1
            aside.append(character)
        case ")" where depth > 0:
            depth -= 1
            aside.append(character)
            if depth == 0 {
                if !matching(aside) { kept += aside }
                aside = ""
            }
        default:
            if depth == 0 { kept.append(character) } else { aside.append(character) }
        }
    }
    return kept + aside
}

/// Senses that only point elsewhere. Not "classifier for", which is what a measure word
/// like 辆 means, nor "surname" before anything but a name, as in 姓名's "surname and
/// given name".
let referencePrefixes = [
    "variant of", "old variant of", "archaic variant of", "unofficial variant of",
    "Japanese variant of", "erhua variant of", "used in ", "see ", "CL:", "abbr. for", "abbr. of",
    "also written", "also pr.", "Taiwan pr.",
]

func pointsElsewhere(_ text: String) -> Bool {
    referencePrefixes.contains(where: text.hasPrefix)
        || text.range(of: "^surname [A-Z]", options: .regularExpression) != nil
}

/// What an abbreviation stands for, when the sense says it in English around the
/// reference: 欧盟's "abbr. for 歐洲聯盟|欧洲联盟[Ou1 zhou1 Lian2 meng2], European Union", or
/// 湘's "abbr. for Hunan 湖南 province in south central China". Nil for one that only points.
func abbreviated(_ raw: String) -> String? {
    guard let prefix = ["abbr. for ", "abbr. of "].first(where: raw.hasPrefix) else { return nil }
    let rest = strippingReferences(String(raw.dropFirst(prefix.count)))
        .split(separator: " ", omittingEmptySubsequences: true)
        .joined(separator: " ")
        .trimmingCharacters(in: CharacterSet(charactersIn: " ,;."))
    return rest.isEmpty ? nil : rest
}

/// Removes inline references like `陝西省|陕西省[Shan3 xi1 Sheng3]`.
func strippingReferences(_ text: String) -> String {
    text.replacingOccurrences(
        of: "[\\p{Han}|]+(\\[[^\\]]*\\])?",
        with: "",
        options: .regularExpression
    )
}

/// The headword a cross reference like `see 西安市[Xi1 an1 Shi4]` points at.
func referencedHeadword(_ gloss: String) -> String? {
    let prefixes = ["see ", "variant of ", "erhua variant of ", "old variant of ", "also written ", "abbr. for ", "abbr. of "]
    guard prefixes.contains(where: gloss.hasPrefix),
          let match = gloss.range(of: "[\\p{Han}|]+(?=\\[)", options: .regularExpression)
    else { return nil }
    return gloss[match].split(separator: "|").last.map(String.init)
}

/// A sense worth keeping, or nil for a cross reference, a surname or a measure word list.
/// Asides are kept, since they say how a sense is used, unless they only point elsewhere.
func sense(_ raw: String) -> String? {
    if let expansion = abbreviated(raw) { return sense(expansion) }
    if pointsElsewhere(raw) { return nil }
    let text = strippingReferences(strippingAsides(raw, containing: isReference))
        .replacingOccurrences(of: "\\s+([,;])", with: "$1", options: .regularExpression)
        .replacingOccurrences(of: "; ", with: ", ")
        .split(separator: " ", omittingEmptySubsequences: true)
        .joined(separator: " ")
        .trimmingCharacters(in: CharacterSet(charactersIn: " ,;."))
    if text.isEmpty || text.contains("[") || text.unicodeScalars.contains(where: isHan) { return nil }
    if text == "()" || pointsElsewhere(text) { return nil }
    // A sense that is only an aside, like "(used in place names)", reads as its inside.
    var plain = strippingAsides(text, containing: { _ in true }).trimmingCharacters(in: .whitespaces)
    if plain.isEmpty { plain = String(text.dropFirst().dropLast()) }
    if pointsElsewhere(plain) { return nil }
    return text
}

/// An aside that points elsewhere, like `(Taiwan pr. [xing4])` or `(used with 得[de2])`.
func isReference(_ aside: String) -> Bool { aside.contains("[") || aside.unicodeScalars.contains(where: isHan) }

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

/// How many entries' traditional forms hold each character. 年 has a second line under the
/// archaic 秊, "grain, harvest (old)", with more senses than 年's own "year". Between lines of
/// one reading, a traditional form at least `rareFactor` times rarer loses. Only then: 里's
/// 裡, "inside", and 里, the unit of length, are both in common use, and 裡 is the one meant.
let traditionalUse: [Character: Int] = {
    var counts: [Character: Int] = [:]
    for entry in entries {
        for character in Set(entry.traditional) { counts[character, default: 0] += 1 }
    }
    return counts
}()

let rareFactor = 20

func traditionalScore(_ entry: Entry) -> Int {
    entry.traditional.map { traditionalUse[$0] ?? 0 }.min() ?? 0
}

/// True when `a` is the common form and `b` a rare one of the same reading.
func isCommonerForm(_ a: Entry, than b: Entry) -> Bool {
    a.pinyin.lowercased() == b.pinyin.lowercased() && traditionalScore(a) >= rareFactor * max(1, traditionalScore(b))
}

func rank(_ candidates: [Entry]) -> Entry {
    let system = candidates[0].simplified.count == 1 ? systemReading(candidates[0].simplified) : nil
    return candidates.min { a, b in
        let aGlosses = a.glosses.compactMap(sense).count
        let bGlosses = b.glosses.compactMap(sense).count
        if (aGlosses > 0) != (bGlosses > 0) { return aGlosses > 0 }
        if a.isProperNoun != b.isProperNoun { return !a.isProperNoun }
        if let system {
            let (aMatches, bMatches) = (displayPinyin(a.pinyin) == system, displayPinyin(b.pinyin) == system)
            if aMatches != bMatches { return aMatches }
        }
        let (aScore, bScore) = (compoundScore(a), compoundScore(b))
        if aScore != bScore { return aScore > bScore }
        if isCommonerForm(a, than: b) { return true }
        if isCommonerForm(b, than: a) { return false }
        if aGlosses != bGlosses { return aGlosses > bGlosses }
        return a.order < b.order
    }!
}

let grouped = Dictionary(grouping: entries, by: \.simplified)
let preferred = Set(grouped.values.map { rank($0).order })
let sensesByOrder = Dictionary(uniqueKeysWithValues: entries.map { ($0.order, $0.glosses.compactMap(sense)) })
let preferredSenses = Dictionary(uniqueKeysWithValues: grouped.map { ($0.key, sensesByOrder[rank($0.value).order] ?? []) })

var lines = ["# CC-CEDICT \(date), CC BY-SA 4.0, https://cc-cedict.org"]
var empty = 0
for entry in entries.sorted(by: { ($0.simplified, $0.order) < ($1.simplified, $1.order) }) {
    var senses = sensesByOrder[entry.order] ?? []
    if senses.isEmpty {
        // A pure cross reference, like 西安's "see 西安市", takes the senses it points at.
        senses = entry.glosses.lazy.compactMap(referencedHeadword).compactMap { preferredSenses[$0] }.first { !$0.isEmpty } ?? []
    }
    if senses.isEmpty { empty += 1 }
    let isPreferred = preferred.contains(entry.order) ? "1" : "0"
    lines.append([entry.simplified, entry.traditional, displayPinyin(entry.pinyin), isPreferred, senses.joined(separator: "\u{1F}")].joined(separator: "\t"))
}
try (lines.joined(separator: "\n") + "\n").write(toFile: arguments[2], atomically: true, encoding: .utf8)
print("\(lines.count - 1) entries for \(grouped.count) headwords, \(empty) with no senses")
