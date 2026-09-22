import Foundation

/// Decides whether a spoken or typed answer matches the word being asked for.
///
/// Comparing Hanzi directly does not work. 是, 事, 试 and 势 are all `shì`, and a
/// recogniser given a single isolated word has no context to pick between them, so it
/// returns whichever character is most common. The user says the right thing and gets
/// marked wrong.
///
/// So everything is reduced to toneless pinyin before comparing. Tones are dropped
/// deliberately: a recogniser's tone output reflects its own guess as much as the
/// speaker's, so grading on tone would fail people for reasons they cannot diagnose.
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

    /// Lowercase pinyin letters only: no tone marks, no tone digits, no spaces or
    /// punctuation. Hanzi is converted on the way through.
    static func normalised(_ text: String) -> String {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return "" }

        if containsHan(working) {
            working = mandarinLatin(working)
        }

        // Folding turns shuǐ into shui and ǜ into u.
        working = working.folding(
            options: .diacriticInsensitive,
            locale: Locale(identifier: "en_US_POSIX")
        )

        // Keeping only a-z drops spaces, apostrophes and tone digits in one pass.
        let letters = working.lowercased().unicodeScalars.filter {
            $0.value >= 97 && $0.value <= 122
        }

        // People type lv for lü, which folds to lu from the other direction.
        return String(String.UnicodeScalarView(letters)).replacingOccurrences(of: "v", with: "u")
    }

    /// Every spelling that counts as right, including the pinyin derived from the Hanzi.
    ///
    /// Both sources are kept because they disagree on neutral tones: 学生 is stored as
    /// `xuésheng`, while the transform produces `xuéshēng`.
    static func acceptedForms(of pair: WordPair) -> Set<String> {
        var forms: Set<String> = []
        for source in [pair.hanzi, pair.pinyin] {
            let form = normalised(source)
            if !form.isEmpty { forms.insert(form) }
        }
        return forms
    }

    static func isCorrect(_ response: String, for pair: WordPair) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed == pair.hanzi { return true }

        let answer = normalised(trimmed)
        guard !answer.isEmpty else { return false }
        return acceptedForms(of: pair).contains(answer)
    }

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
