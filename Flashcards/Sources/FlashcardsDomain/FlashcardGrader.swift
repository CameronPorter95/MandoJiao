import Foundation
import VocabularyDomain

/// Whether a typed flash card answer is right. Picked answers need no grading: the option
/// is the word or it is not.
public nonisolated enum FlashcardGrader {
    /// Whether the text can be checked at all. A card showing English takes Hanzi only, so
    /// pinyin or English typed into it is turned away rather than marked wrong; a card
    /// showing Chinese takes English, so Hanzi is turned away there.
    public static func canCheck(_ text: String, for card: Flashcard) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let han = trimmed.unicodeScalars.filter(isHan).count
        let letters = trimmed.unicodeScalars.filter { $0.properties.isAlphabetic && !isHan($0) }.count
        return card.showsChinese ? han == 0 : han > 0 && letters == 0
    }

    public static func isCorrect(_ text: String, for card: Flashcard) -> Bool {
        guard canCheck(text, for: card) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !card.showsChinese {
            let typed = trimmed.filter { !$0.isWhitespace }
            return typed == card.word.hanzi || card.alsoAccepted.contains(typed)
        }
        let typed = normalised(trimmed)
        guard !typed.isEmpty else { return false }
        return acceptedForms(of: card.word).contains { form in
            form == typed || (form.count >= typoFloor && distance(form, typed, limit: 1) <= 1)
        }
    }

    /// Answers this long or longer may have one letter wrong, missing or extra. Shorter
    /// ones must be exact: "tea" one letter off is "ten" or "sea".
    public static let typoFloor = 5

    /// Every meaning, and each part of one with several: "to tell, to inform" takes "tell"
    /// and "inform" as well as the whole.
    public static func acceptedForms(of word: WordPair) -> Set<String> {
        var forms = Set<String>()
        for meaning in word.meanings {
            let plain = Gloss.plain(meaning, limit: .max)
            forms.insert(normalised(plain))
            for part in plain.split(whereSeparator: { ",;".contains($0) }) {
                forms.insert(normalised(String(part)))
            }
        }
        forms.remove("")
        return forms
    }

    /// Lowercased, asides in brackets and punctuation dropped, spaces collapsed, and a
    /// leading "to", "a", "an" or "the" taken off, so "To Drink!" is "drink".
    public static func normalised(_ text: String) -> String {
        var depth = 0
        var kept = ""
        for character in text.lowercased() {
            switch character {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            default:
                guard depth == 0 else { continue }
                kept.append(character.isLetter || character.isNumber || character == "'" ? character : " ")
            }
        }
        var words = kept.split(separator: " ").map(String.init)
        if words.count > 1, ["to", "a", "an", "the"].contains(words[0]) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    /// Edit distance, giving up past `limit`.
    static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= limit else { return limit + 1 }
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x9FFF).contains(scalar.value) || (0x20000...0x2FFFF).contains(scalar.value)
    }
}
