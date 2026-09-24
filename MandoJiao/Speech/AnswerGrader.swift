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
        let candidates = runs(of: heard)

        // Matching inside a phrase is not gated by strictness. The extra words are the
        // recogniser padding a single word into something sentence-shaped, not the
        // speaker getting anything wrong: saying 完成 and having it come back as 完成了
        // is a correct answer however strict the setting.
        //
        // `runs` includes the whole transcript, so this covers an exact match too.
        // Comparing runs joined rather than syllable by syllable matters because the two
        // sides disagree about where syllables break: 完成 transforms to two syllables,
        // while the same word typed in as "wancheng" arrives as one token.
        if candidates.contains(expectedJoined) { return true }

        if strictness.allowsVowelConfusions || strictness.allowsNasalFinals {
            let key = canonical(expectedJoined, for: strictness)
            if candidates.contains(where: { canonical($0, for: strictness) == key }) {
                return true
            }
        }

        // Nothing below here applies to any level but the loosest.
        guard strictness.allowsNearSpellings else { return false }

        let expectedKey = folded(canonical(expectedJoined, for: strictness))
        let allowance = allowance(for: expectedKey)

        return candidates.contains {
            editDistance(folded(canonical($0, for: strictness)), expectedKey) <= allowance
        }
    }

    /// The spelling a level compares on, with whatever that level treats as the same
    /// sound collapsed together.
    private static func canonical(_ key: String, for strictness: MatchStrictness) -> String {
        var result = key
        if strictness.allowsVowelConfusions { result = vowelFolded(result) }
        if strictness.allowsNasalFinals { result = nasalFolded(result) }
        return result
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

    /// Collapses the vowel in a syllable-final -ng, so -ang, -eng and -ong are one ending.
    ///
    /// This is the confusion behind 完成 coming back as 晚昌 or 晚冲: the initial is
    /// right, the nasal is right, only the vowel in front of it differs.
    ///
    /// -ing is left alone, so 明 and 忙 stay apart. The compound finals keep their medial
    /// and so stay distinct too: -uang does not become -ang, which is what keeps 晚窗
    /// (chuang) from counting as 完成 (cheng).
    ///
    /// The cost is that 想 (xiǎng) and 兄 (xiōng) become indistinguishable.
    private static func nasalFolded(_ key: String) -> String {
        var result = key
        for vowel in ["a", "e", "o"] {
            result = result.replacingOccurrences(of: "\(vowel)ng", with: "Ang")
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
