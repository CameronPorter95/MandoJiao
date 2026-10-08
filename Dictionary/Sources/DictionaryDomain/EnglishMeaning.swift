import Foundation

/// Whether an English translation says a meaning, so an example sentence can be held to the
/// sense on the card: 打 "to hit" is not taught with 打电话's "I'll call you".
///
/// Words are compared by a rough stem, with the common irregular forms, so "hits", "hitting"
/// and "friend's" say "hit" and "friend". A meaning says itself when all the content words of
/// any one of its comma-separated parts appear: "to see, to look at" is said by "Did they
/// see us?". Paraphrase is beyond it: "Give me a ring" does not say "to call".
public nonisolated enum EnglishMeaning {
    /// Whether a meaning has anything to check: 了's "(completed action marker)" does not.
    public static func isCheckable(_ meaning: String) -> Bool {
        !parts(of: meaning).isEmpty
    }

    public static func says(_ meaning: String, in english: String) -> Bool {
        let said = stems(of: english)
        return parts(of: meaning).contains { $0.isSubset(of: said) }
    }

    /// Each comma- or semicolon-separated part's content words, asides dropped.
    static func parts(of meaning: String) -> [Set<String>] {
        let plain = meaning.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        return plain.split(whereSeparator: { ",;/".contains($0) }).compactMap { part in
            let words = Set(words(in: String(part)).filter { !stopWords.contains($0) }.map(stem))
            return words.isEmpty ? nil : words
        }
    }

    static func stems(of text: String) -> Set<String> {
        Set(words(in: text).map(stem))
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "'s\\b", with: "", options: .regularExpression)
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { !$0.isEmpty }
    }

    static func stem(_ word: String) -> String {
        let stem = irregular[word] ?? regularStem(word)
        return variants[stem] ?? stem
    }

    /// Spellings and words that name the same thing, by stem, met at one: a starter card says
    /// "aeroplane" where Tatoeba's translations say "plane" and "airplane", and the British
    /// spellings a learner may type meet the American ones Tatoeba mostly uses.
    private static let variants: [String: String] = [
        "aeroplan": "plan", "airplan": "plan", "colour": "color", "favourit": "favorit",
        "centr": "center", "theatr": "theater", "metr": "meter", "litr": "liter", "flavour": "flavor",
        "neighbour": "neighbor", "honour": "honor", "organis": "organiz", "realis": "realiz", "mum": "mom",
        "grey": "gray", "programm": "program", "travell": "travel", "tyr": "tir", "pyjama": "pajama",
        "chequ": "check",
    ]

    /// "see" and "seeing", "drive" and "driving" meet at "se" and "driv"; "hitting" and
    /// "stopped" lose their doubled consonant, "falling" and "kissing" keep theirs.
    private static func regularStem(_ word: String) -> String {
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

    private static let suffixes: [(String, String)] = [
        ("ies", "y"), ("ied", "y"), ("ing", ""), ("ed", ""), ("es", ""), ("s", ""), ("ly", ""),
    ]

    /// Words a meaning uses to frame itself, never what it means.
    private static let stopWords: Set<String> = [
        "a", "an", "the", "of", "to", "be", "sb", "sth", "one", "one's", "oneself", "etc", "or", "and",
        "in", "on", "at", "for", "with", "by", "as", "up", "out", "is", "it", "something", "someone",
        "somebody", "used", "particle", "classifier", "~",
    ]

    private static let irregular: [String: String] = [
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
    // The base's own stem, so "saw" and "seeing" both meet "see" at "se".
    ].mapValues(regularStem)
}
