import Foundation

/// Decides whether a spoken or typed answer matches the word being asked for.
///
/// Comparing Hanzi directly does not work. 是, 事, 试 and 势 are all `shì`, and a
/// recogniser given a single isolated word has no context to pick between them, so it
/// returns whichever character is most common. The user says the right thing and gets
/// marked wrong.
///
/// So everything is reduced to toneless pinyin syllables before comparing. Tones are
/// dropped deliberately: a recogniser's tone output reflects its own guess as much as
/// the speaker's, so grading on tone would fail people for reasons they cannot diagnose.
///
/// Accepted consequence: homophones pass. Answering 事 when asked for 是 is marked
/// correct, because audio alone cannot tell them apart.
enum AnswerGrader {
    static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)        // CJK Unified Ideographs
                || (0x3400...0x4DBF).contains(scalar.value) // Extension A
                || (0xF900...0xFAFF).contains(scalar.value) // Compatibility Ideographs
        }
    }

    /// Toneless pinyin, one entry per syllable.
    ///
    /// Syllables are kept apart rather than run together because matching a word inside
    /// a longer phrase has to respect syllable boundaries. Flat-string containment would
    /// accept 完成 (`wancheng`) as an answer for 喝 (`he`), since "cheng" contains "he".
    static func syllables(_ text: String) -> [String] {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return [] }

        if containsHan(working) {
            // The transform emits one space-separated syllable per character.
            working = mandarinLatin(working)
        }

        return working
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map { token in
                let letters = token.unicodeScalars.filter { $0.value >= 97 && $0.value <= 122 }
                // People type lv for lü, which folds to lu from the other direction.
                return String(String.UnicodeScalarView(letters))
                    .replacingOccurrences(of: "v", with: "u")
            }
            .filter { !$0.isEmpty }
    }

    /// Lowercase pinyin letters only: no tone marks, no tone digits, no spaces.
    static func normalised(_ text: String) -> String {
        syllables(text).joined()
    }

    /// Every spelling that counts as right, as syllables.
    ///
    /// Both the Hanzi and the stored pinyin are kept. They can disagree on syllable
    /// boundaries: a word typed in as `wánchéng` is one token, while the same word's
    /// Hanzi transforms to `wán chéng`, two. Keeping both means matching inside a phrase
    /// still works whichever way the word was entered.
    static func acceptedSyllableForms(of pair: WordPair) -> [[String]] {
        var forms: [[String]] = []
        for source in [pair.hanzi, pair.pinyin] {
            let form = syllables(source)
            if !form.isEmpty, !forms.contains(form) {
                forms.append(form)
            }
        }
        return forms
    }

    static func acceptedForms(of pair: WordPair) -> Set<String> {
        Set(acceptedSyllableForms(of: pair).map { $0.joined() })
    }

    static func isCorrect(
        _ response: String,
        for pair: WordPair,
        strictness: MatchStrictness = .default
    ) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed == pair.hanzi { return true }

        let heard = syllables(trimmed)
        guard !heard.isEmpty else { return false }

        return acceptedSyllableForms(of: pair).contains { expected in
            matches(heard: heard, expected: expected, strictness: strictness)
        }
    }

    /// Grades the recogniser's best guess and, where the setting allows, the alternatives
    /// it offered alongside it.
    static func isCorrect(
        _ outcome: SpeechOutcome,
        for pair: WordPair,
        strictness: MatchStrictness = .default
    ) -> Bool {
        if isCorrect(outcome.best, for: pair, strictness: strictness) { return true }
        guard strictness.allowsAlternatives else { return false }
        return outcome.alternatives.contains { isCorrect($0, for: pair, strictness: strictness) }
    }

    // MARK: - Matching

    private static func matches(
        heard: [String],
        expected: [String],
        strictness: MatchStrictness
    ) -> Bool {
        let expectedJoined = expected.joined()

        // Joined rather than element-wise, because the two sides disagree about where
        // syllables break: 完成 transforms to two syllables, while the same word typed in
        // as "wancheng" arrives as one token.
        if heard.joined() == expectedJoined { return true }

        if strictness.allowsSurroundingWords,
           runs(of: heard).contains(expectedJoined) {
            return true
        }

        if strictness.allowsVowelConfusions {
            let vowelKey = vowelFolded(expectedJoined)
            if vowelFolded(heard.joined()) == vowelKey { return true }
            if strictness.allowsSurroundingWords,
               runs(of: heard).contains(where: { vowelFolded($0) == vowelKey }) {
                return true
            }
        }

        // Nothing below this point applies to any level but lenient, and lenient allows
        // everything above, so there is no second check to make on the level here.
        guard strictness.allowsNearSpellings else { return false }

        let expectedKey = folded(vowelFolded(expectedJoined))
        let allowance = allowance(for: expectedKey)

        if editDistance(folded(vowelFolded(heard.joined())), expectedKey) <= allowance {
            return true
        }

        return runs(of: heard).contains {
            editDistance(folded(vowelFolded($0)), expectedKey) <= allowance
        }
    }

    /// Every contiguous run of syllables, joined.
    ///
    /// Runs start and end on a syllable, which is what stops a short word being found
    /// inside an unrelated longer one: 喝 is "he" and 完成 is "wancheng", which contains
    /// those letters but never as a whole syllable.
    private static func runs(of syllables: [String]) -> [String] {
        var result: [String] = []
        for start in syllables.indices {
            var joined = ""
            for end in start..<syllables.count {
                joined += syllables[end]
                result.append(joined)
            }
        }
        return result
    }

    /// Collapses the empty-rime syllables onto their -e counterparts: zhi with zhe, shi
    /// with she, zi with ze, and the rest.
    ///
    /// The vowel in zhi, chi, shi, ri, zi, ci and si is not an [i]. It is the initial
    /// consonant held on, and it sits close enough to -e that recognisers swap them
    /// constantly: 知道 comes back as 这倒 over and over.
    ///
    /// Safe to run on a joined string. Each of these initials only ever begins a
    /// syllable, and none of them takes a further vowel after the i, so the sequence
    /// "zhi" in run-together pinyin is always the syllable zhi and never a boundary
    /// crossing. "shui" is not affected, since its letters are s-h-u-i.
    ///
    /// The cost is real but narrow: 是 (shì) and 社 (shè) become indistinguishable.
    private static func vowelFolded(_ key: String) -> String {
        var result = key
        for initial in ["zh", "ch", "sh", "r", "z", "c", "s"] {
            result = result.replacingOccurrences(of: "\(initial)i", with: "\(initial)e")
        }
        return result
    }

    /// Collapses the pairs learners and recognisers most often swap: the retroflex
    /// initials against their alveolar counterparts, and the -ng ending against -n.
    private static func folded(_ key: String) -> String {
        var result = key
        for (from, to) in [("zh", "z"), ("ch", "c"), ("sh", "s")] {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result.replacingOccurrences(of: "ng", with: "n")
    }

    /// One letter of slack per syllable's worth of word, capped at two. A short word gets
    /// none: with three letters to play with, half the syllables in the language are one
    /// edit apart.
    private static func allowance(for key: String) -> Int {
        min(2, key.count / 4)
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 0 }
        let left = Array(lhs)
        let right = Array(rhs)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = [Int](repeating: 0, count: right.count + 1)

        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let substitution = previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            previous = current
        }

        return previous[right.count]
    }

    // MARK: - Display

    /// Pinyin with tone marks, for showing the answer once a card is over.
    static func pinyinWithTones(_ hanzi: String) -> String {
        guard containsHan(hanzi) else { return hanzi }
        return mandarinLatin(hanzi)
    }

    private static func mandarinLatin(_ text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformMandarinLatin, false)
        return mutable as String
    }
}
