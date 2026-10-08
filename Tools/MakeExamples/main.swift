import Foundation

// Builds the example sentences: for each dictionary reading Tatoeba uses, up to ten short
// sentences, easiest first, each with its pinyin, an English translation and its words. Ten
// rather than one, so the app can choose the sentence the learner knows most words of.
//
// Download from https://tatoeba.org/en/downloads into one folder: the Mandarin and English
// sentences and the Mandarin-English links (per_language/cmn/cmn_sentences.tsv,
// per_language/eng/eng_sentences.tsv, per_language/cmn/cmn-eng_links.tsv) and
// transcriptions.csv from transcriptions.tar.bz2. Then run from the repository root:
//   swift Tools/MakeExamples/main.swift <folder> Dictionary/Sources/DictionaryData/Resources/Examples.tsv
//
// Every sentence with a pinyin transcription and an English translation is used, in
// simplified characters: Tatoeba transcribes each sentence written in traditional into
// simplified (a `Hans` transcription), and one written in simplified into traditional. The
// transcription splits a sentence into words, and a word only
// has a sentence as an example where it is whole words of that split and its pinyin is the
// reading's: 长 cháng is never shown with 他长大了, where it is zhǎng.
//
// Two kinds of line, tab separated. `S`, a sentence: its Tatoeba id, Hanzi, pinyin with
// tone marks, English, and its words as their lengths in Han characters, comma separated:
// "2,1,1,2" is 学生 是 我 朋友 in 学生是我朋友. `W`, a reading: simplified, pinyin as the dictionary writes it, and
// its sentences' ids, best first, comma separated. Tatoeba's sentences are CC BY 2.0 FR, so
// the output is too, and its header line carries the attribution.

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: main.swift <tatoeba folder> <Examples.tsv>\n".utf8))
    exit(1)
}
let folder = URL(fileURLWithPath: arguments[1])
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appending(path: "Dictionary/Sources/DictionaryData/Resources")

/// The examples kept for each reading. Measured on Tatoeba's 2026-10 export: a learner who
/// knows the starter words and HSK 1, learning HSK 2, finds a sentence of only known words
/// for 62% of words with 3, 74% with 10, 77% with 20 or every one, and the file is 5.9 MB at
/// 10. A learner a few days in finds almost none at any number: those are left to the
/// fewest unknown words.
let perReading = 10
/// A reading's meanings each given a sentence of its own, where the easiest ten have none:
/// an HSK word's own, then the dictionary's first senses.
let senseLimit = 6
/// Han characters in a sentence worth showing a learner on one card.
let lengthLimit = 4...16
/// The length a sentence is best at: long enough to show the word in use.
let idealLength = 8

func lines(_ name: String, in directory: URL) throws -> [Substring] {
    try String(contentsOf: directory.appending(path: name), encoding: .utf8).split(separator: "\n")
}

func isMark(_ character: Character) -> Bool {
    character.isPunctuation || character.isSymbol
}

/// Punctuation that opens rather than closes, so it goes with the word after it.
func opens(_ character: Character) -> Bool {
    "“‘「『（(《〈[".contains(character)
}

func isHan(_ character: Character) -> Bool {
    character.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x2FFFF).contains($0.value) }
}

// MARK: Pinyin

/// One syllable as letters and a tone, 5 for neutral, so tone marks and tone numbers
/// compare alike.
struct Syllable: Hashable {
    let letters: String
    let tone: Int
}

let marks: [Character: (Character, Int)] = {
    var table: [Character: (Character, Int)] = [:]
    let rows: [(Character, String)] = [("a", "āáǎà"), ("e", "ēéěè"), ("i", "īíǐì"), ("o", "ōóǒò"), ("u", "ūúǔù"), ("ü", "ǖǘǚǜ")]
    for (base, marked) in rows {
        for (index, character) in marked.enumerated() { table[character] = (base, index + 1) }
    }
    return table
}()

/// "yínháng" or "yín háng" as syllables. Split where a syllable could end: before a
/// consonant that starts the next one. Only used on the dictionary's readings, which put
/// syllables of a word together, so it is checked against the transcription's own split.
func syllables(marked pinyin: String) -> [Syllable] {
    var result: [Syllable] = []
    for word in pinyin.lowercased().split(whereSeparator: { !$0.isLetter && !marks.keys.contains($0) }) {
        var letters = ""
        var parts: [(String, Int)] = []
        for character in word {
            if let (base, _) = marks[character] {
                letters.append(base)
            } else {
                letters.append(character)
            }
        }
        // Re-split letters into syllables with a greedy longest match against the
        // syllable inventory, carrying each mark to the syllable it was written in.
        var index = letters.startIndex
        var toneIndex = word.startIndex
        while index < letters.endIndex {
            let rest = letters[index...]
            let length = (1...min(6, rest.count)).reversed().first { inventory.contains(String(rest.prefix($0))) } ?? rest.count
            let end = letters.index(index, offsetBy: length)
            let original = word[toneIndex..<word.index(toneIndex, offsetBy: length)]
            let syllableTone = original.compactMap { marks[$0]?.1 }.first ?? 5
            parts.append((String(letters[index..<end]), syllableTone))
            index = end
            toneIndex = word.index(toneIndex, offsetBy: length)
        }
        result += parts.map { Syllable(letters: $0.0, tone: $0.1) }
    }
    return result
}

/// "xue2sheng5" or "Wo3" as syllables.
func syllables(numbered token: Substring) -> [Syllable]? {
    var result: [Syllable] = []
    var letters = ""
    for character in token.lowercased() {
        if let tone = character.wholeNumberValue, (1...5).contains(tone) {
            guard !letters.isEmpty else { return nil }
            result.append(Syllable(letters: letters.replacingOccurrences(of: "u:", with: "ü").replacingOccurrences(of: "v", with: "ü"), tone: tone))
            letters = ""
        } else if character.isLetter || character == ":" {
            letters.append(character)
        } else {
            return nil
        }
    }
    return letters.isEmpty ? result : nil
}

/// Tone marks on numbered syllables, where Hanyu Pinyin puts them: on a or e, on the o of
/// ou, otherwise on the last vowel.
func marked(_ syllable: Syllable) -> String {
    let letters = syllable.letters
    guard (1...4).contains(syllable.tone) else { return letters }
    let vowels = Array("aeiouü")
    let target: String.Index? = {
        if let a = letters.firstIndex(where: { $0 == "a" || $0 == "e" }) { return a }
        if let o = letters.range(of: "ou")?.lowerBound { return o }
        return letters.lastIndex(where: vowels.contains)
    }()
    guard let target else { return letters }
    let base = letters[target]
    let markedCharacter = marks.first { $0.value.0 == base && $0.value.1 == syllable.tone }?.key ?? base
    return letters.replacingCharacters(in: target...target, with: String(markedCharacter))
}

/// Every Mandarin syllable, for splitting the dictionary's run-together pinyin.
let inventory: Set<String> = {
    let initials = ["", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]
    let finals = ["a", "o", "e", "i", "u", "ü", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "er", "ia", "ie", "iao", "iu", "ian", "in", "iang", "ing", "iong", "ua", "uo", "uai", "ui", "uan", "un", "uang", "üe", "üan", "ün", "ue", "r"]
    return Set(initials.flatMap { initial in finals.map { initial + $0 } })
}()

/// Whether a sentence says a reading: same letters, and the same tones except where the
/// written tone is not the spoken one. 不 and 一, whose tones change before the next
/// syllable, match any tone. A neutral tone on either side matches any tone only within a
/// longer word, as 学生's -sheng is written both ways: a one-syllable word's tone is all
/// that tells its readings apart, as 了's liǎo and liào, and an unmarked "liao" says neither.
func says(_ heard: [Syllable], _ reading: [Syllable], hanzi: [Character], loosely: Bool = true) -> Bool {
    guard heard.count == reading.count else { return false }
    let neutralMatches = loosely && reading.count > 1
    return zip(zip(heard, reading), hanzi).allSatisfy { pair, character in
        let (said, wanted) = pair
        guard said.letters == wanted.letters else { return false }
        if said.tone == wanted.tone || character == "不" || character == "一" { return true }
        return neutralMatches && (said.tone == 5 || wanted.tone == 5)
    }
}

// MARK: Sources

struct Reading {
    let simplified: String
    let pinyin: String
    let syllables: [Syllable]
}

var readings: [String: [Reading]] = [:]
/// Each reading's meanings, by "simplified\tpinyin": an HSK word's own first, then the
/// dictionary's senses.
var meanings: [String: [String]] = [:]
for line in try lines("Dictionary.tsv", in: resources) where !line.hasPrefix("#") {
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
    let simplified = String(fields[0])
    let pinyin = String(fields[2])
    if fields.count > 4 {
        meanings["\(simplified)\t\(pinyin)", default: []] += fields[4].split(separator: "\u{1F}").prefix(6).map(String.init)
    }
    let parsed = syllables(marked: pinyin)
    guard parsed.count == simplified.filter(isHan).count, simplified.allSatisfy(isHan) else { continue }
    if readings[simplified]?.contains(where: { $0.pinyin == pinyin }) == true { continue }
    readings[simplified, default: []].append(Reading(simplified: simplified, pinyin: pinyin, syllables: parsed))
}

/// The lowest HSK level of each word, so a sentence can be judged by its hardest word.
var level: [String: Int] = [:]
for line in try lines("HSK.tsv", in: resources) where !line.hasPrefix("#") {
    let fields = line.split(separator: "\t")
    let word = String(fields[2])
    level[word] = min(level[word] ?? 7, Int(fields[0])!)
    // An HSK word's meanings are what a library copy of it shows, so its sentences cover those.
    if fields.count > 4 {
        let key = "\(word)\t\(fields[3])"
        meanings[key] = fields[4].split(separator: "\u{1F}").map(String.init) + (meanings[key] ?? [])
    }
}

// MARK: Meanings

// A copy of DictionaryDomain's EnglishMeaning, since a tool script cannot import the
// package: whether an English translation says a meaning, by rough stems. Keep the two alike.

let stopWords: Set<String> = [
    "a", "an", "the", "of", "to", "be", "sb", "sth", "one", "one's", "oneself", "etc", "or", "and",
    "in", "on", "at", "for", "with", "by", "as", "up", "out", "is", "it", "something", "someone",
    "somebody", "used", "particle", "classifier", "~",
]
let suffixes: [(String, String)] = [("ies", "y"), ("ied", "y"), ("ing", ""), ("ed", ""), ("es", ""), ("s", ""), ("ly", "")]
func regularStem(_ word: String) -> String {
    var word = word
    for (suffix, replacement) in suffixes where word.hasSuffix(suffix) && word.count - suffix.count >= 3 {
        word = String(word.dropLast(suffix.count)) + replacement
        if suffix == "ing" || suffix == "ed", let last = word.last, word.dropLast().last == last,
           !"aeioulsfz".contains(last) {
            word.removeLast()
        }
        break
    }
    return word.hasSuffix("e") && word.count > 2 ? String(word.dropLast()) : word
}
let irregular: [String: String] = [
    "went": "go", "gone": "go", "goes": "go", "ate": "eat", "eaten": "eat", "bought": "buy",
    "saw": "see", "seen": "see", "said": "say", "says": "say", "did": "do", "done": "do", "does": "do",
    "made": "make", "took": "take", "taken": "take", "came": "come", "gave": "give", "given": "give",
    "got": "get", "gotten": "get", "had": "have", "has": "have", "knew": "know", "known": "know",
    "thought": "think", "told": "tell", "wrote": "write", "written": "write", "sat": "sit",
    "stood": "stand", "slept": "sleep", "drank": "drink", "drunk": "drink", "ran": "run", "sold": "sell",
    "taught": "teach", "learnt": "learn", "heard": "hear", "left": "leave", "lost": "lose", "met": "meet",
    "paid": "pay", "spoke": "speak", "spoken": "speak", "began": "begin", "begun": "begin",
    "brought": "bring", "felt": "feel", "found": "find", "flew": "fly", "drove": "drive",
    "driven": "drive", "children": "child", "men": "man", "women": "woman", "people": "person",
    "better": "good", "best": "good", "was": "be", "were": "be", "are": "be", "am": "be", "been": "be",
].mapValues(regularStem)
func englishWords(_ text: String) -> [String] {
    text.lowercased()
        .replacingOccurrences(of: "'s\\b", with: "", options: .regularExpression)
        .split(whereSeparator: { !$0.isLetter && $0 != "'" })
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
        .filter { !$0.isEmpty }
}
func stem(_ word: String) -> String { irregular[word] ?? regularStem(word) }
func meaningParts(_ meaning: String) -> [Set<String>] {
    let plain = meaning.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
    return plain.split(whereSeparator: { ",;/".contains($0) }).compactMap { part in
        let words = Set(englishWords(String(part)).filter { !stopWords.contains($0) }.map(stem))
        return words.isEmpty ? nil : words
    }
}
func englishSays(_ meaning: String, _ english: String) -> Bool {
    let said = Set(englishWords(english).map(stem))
    return meaningParts(meaning).contains { $0.isSubset(of: said) }
}

/// The simplified rewrite of a sentence written in traditional.
var simplifiedText: [Int: String] = [:]
var transcription: [Int: (text: Substring, reviewed: Bool)] = [:]
for line in try lines("transcriptions/transcriptions.csv", in: folder) where line.contains("\tcmn\t") {
    let fields = line.split(separator: "\t", maxSplits: 4, omittingEmptySubsequences: false)
    guard fields.count == 5, let id = Int(fields[0]) else { continue }
    switch fields[2] {
    case "Hans": simplifiedText[id] = String(fields[4])
    case "Latn": transcription[id] = (fields[4], !fields[3].isEmpty)
    default: break
    }
}

var english: [Int: Int] = [:]
for line in try lines("cmn-eng_links.tsv", in: folder) {
    let fields = line.split(separator: "\t")
    guard let cmn = Int(fields[0]), let eng = Int(fields[1]) else { continue }
    // The lowest id: usually the original sentence, where later ones are rewordings.
    english[cmn] = min(english[cmn] ?? .max, eng)
}
let wanted = Set(english.values)
var englishText: [Int: String] = [:]
for line in try lines("eng_sentences.tsv", in: folder) {
    guard let tab = line.firstIndex(of: "\t"), let id = Int(line[..<tab]), wanted.contains(id) else { continue }
    englishText[id] = String(line.split(separator: "\t", maxSplits: 2)[2])
}

// MARK: Sentences

struct Sentence {
    let id: Int
    let hanzi: String
    let pinyin: String
    let english: String
    let reviewed: Bool
    /// Han characters, one per syllable.
    let characters: [Character]
    let syllables: [Syllable]
    /// Each transcription word, as a range of characters.
    let words: [Range<Int>]
}

var sentences: [Int: Sentence] = [:]
for line in try lines("cmn_sentences.tsv", in: folder) {
    let fields = line.split(separator: "\t", maxSplits: 2)
    guard fields.count == 3, let id = Int(fields[0]),
          let (text, reviewed) = transcription[id],
          let englishID = english[id], let translation = englishText[englishID]
    else { continue }
    let hanzi = simplifiedText[id] ?? String(fields[2])
    let characters = hanzi.filter(isHan).map { $0 }
    guard lengthLimit.contains(characters.count) else { continue }
    // Digits, Latin letters and the like have no syllable to line up with.
    guard hanzi.allSatisfy({ isHan($0) || $0.isPunctuation || $0.isWhitespace }) else { continue }

    var all: [Syllable] = []
    var words: [Range<Int>] = []
    var shown: [String] = []
    /// An opening mark written apart, as Tatoeba writes `“ ni3hao3 ”`, held for the next word.
    var opening = ""
    var aligned = true
    for token in text.split(separator: " ") {
        let leading = token.prefix(while: isMark)
        let trailing = String(token.reversed().prefix(while: isMark).reversed())
        let core = token.dropFirst(leading.count).dropLast(trailing.count)
        guard !core.isEmpty else {
            // Punctuation on its own closes the word before it, unless it only opens.
            if token.allSatisfy(opens) || shown.isEmpty {
                opening += token
            } else {
                shown[shown.count - 1] += token
            }
            continue
        }
        guard let parsed = syllables(numbered: core) else { aligned = false; break }
        words.append(all.count..<all.count + parsed.count)
        all += parsed
        var written = parsed.map(marked).joined()
        if core.first?.isUppercase == true { written = written.prefix(1).uppercased() + written.dropFirst() }
        shown.append(opening + leading + written + trailing)
        opening = ""
    }
    guard aligned, all.count == characters.count else { continue }
    sentences[id] = Sentence(
        id: id, hanzi: hanzi, pinyin: shown.joined(separator: " "), english: translation,
        reviewed: reviewed, characters: characters, syllables: all, words: words
    )
}

// MARK: Matching

/// How hard a sentence is beside a word: its hardest other word's HSK level, 8 for a word
/// outside the syllabus.
func hardness(_ sentence: Sentence, beside span: Range<Int>) -> Int {
    sentence.words.filter { $0 != span }.map { word in
        level[String(sentence.characters[word])] ?? 8
    }.max() ?? 0
}

var examples: [String: [(sentence: Sentence, key: (Int, Int, Int, Int))]] = [:]
for sentence in sentences.values {
    // A word may span several of the transcription's words, as 多少 does in "duo1 shao5".
    for start in sentence.words.map(\.lowerBound) {
        for end in sentence.words.map(\.upperBound) where end > start && end - start <= 6 {
            let hanzi = String(sentence.characters[start..<end])
            guard let candidates = readings[hanzi] else { continue }
            let heard = Array(sentence.syllables[start..<end])
            // A reading said tone for tone takes the sentence from one only matched loosely:
            // dōngxi's sentences are not dōngxī's, east and west.
            let exact = candidates.filter { says(heard, $0.syllables, hanzi: Array(hanzi), loosely: false) }
            let matched = exact.isEmpty ? candidates.filter { says(heard, $0.syllables, hanzi: Array(hanzi)) } : exact
            for reading in matched {
                let wordLevel = level[hanzi] ?? 7
                let key = (
                    max(hardness(sentence, beside: start..<end), wordLevel),
                    abs(sentence.characters.count - idealLength),
                    sentence.reviewed ? 0 : 1,
                    sentence.id
                )
                examples["\(reading.simplified)\t\(reading.pinyin)", default: []].append((sentence, key))
            }
        }
    }
}

// MARK: Output

var used: [Int: Sentence] = [:]
var readingLines: [String] = []
var extras = 0
for (reading, found) in examples.sorted(by: { $0.key < $1.key }) {
    var seen = Set<Int>()
    let ordered = found.sorted { $0.key < $1.key }.filter { seen.insert($0.sentence.id).inserted }
    var best = Array(ordered.prefix(perReading))
    // The easiest sentence for each meaning the easiest ten leave out, so 打's "to hit" has
    // one beside its many 打电话. Easiest first still, after the ten.
    for meaning in (meanings[reading] ?? []).prefix(senseLimit) where !meaningParts(meaning).isEmpty {
        guard !best.contains(where: { englishSays(meaning, $0.sentence.english) }),
              let extra = ordered.first(where: { candidate in
                  englishSays(meaning, candidate.sentence.english) && !best.contains { $0.sentence.id == candidate.sentence.id }
              })
        else { continue }
        best.append(extra)
        extras += 1
    }
    best.forEach { used[$0.sentence.id] = $0.sentence }
    readingLines.append("W\t\(reading)\t\(best.map { String($0.sentence.id) }.joined(separator: ","))")
}
let sentenceLines = used.values.sorted { $0.id < $1.id }.map {
    "S\t\($0.id)\t\($0.hanzi)\t\($0.pinyin)\t\($0.english.replacingOccurrences(of: "\t", with: " "))\t\($0.words.map { String($0.count) }.joined(separator: ","))"
}
let date = ISO8601DateFormatter.string(from: .now, timeZone: .current, formatOptions: .withFullDate)
let header = "# Tatoeba \(date), CC BY 2.0 FR, https://tatoeba.org"
try ([header] + sentenceLines + readingLines).joined(separator: "\n").appending("\n")
    .write(to: URL(fileURLWithPath: arguments[2]), atomically: true, encoding: .utf8)
print("\(sentenceLines.count) sentences for \(readingLines.count) readings, \(extras) kept for a meaning the easiest left out")
