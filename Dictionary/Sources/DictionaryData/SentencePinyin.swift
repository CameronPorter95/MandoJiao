import DictionaryDomain
import Foundation

/// Pinyin for a sentence the app did not get from Tatoeba, so has no transcription for. The
/// taught word takes the card's own reading wherever it appears; the rest takes the
/// lexicon's, longest pieces first, so 银行 reads yínháng rather than yín xíng. Another
/// polyphone in the sentence takes its preferred reading, which may be wrong for it: a cost
/// of generated sentences that Tatoeba's do not have.
nonisolated enum SentencePinyin {
    /// Nil when the lexicon cannot read some of it.
    static func spell(_ sentence: String, word: String, wordPinyin: String, lexicon: any LexiconRepository) async throws -> String? {
        var spelled: [String] = []
        var run = ""

        func flush() async throws -> Bool {
            guard !run.isEmpty else { return true }
            defer { run = "" }
            for (index, piece) in run.components(separatedBy: word).enumerated() {
                if index > 0 { spelled.append(wordPinyin) }
                guard !piece.isEmpty else { continue }
                guard let pinyin = try await lexicon.suggestion(forHanzi: piece)?.pinyin, !pinyin.isEmpty else { return false }
                spelled.append(pinyin)
            }
            return true
        }

        for character in sentence {
            if isHan(character) {
                run.append(character)
                continue
            }
            guard try await flush() else { return nil }
            if let mark = punctuation[character] {
                if spelled.isEmpty { spelled.append(mark) } else { spelled[spelled.count - 1] += mark }
            }
        }
        guard try await flush(), let first = spelled.first else { return nil }
        spelled[0] = first.prefix(1).uppercased() + first.dropFirst()
        return spelled.joined(separator: " ")
    }

    private static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x2FFFF).contains($0.value) }
    }

    /// Full-width punctuation as pinyin writes it.
    private static let punctuation: [Character: String] = [
        "。": ".", "，": ",", "、": ",", "？": "?", "！": "!", "：": ":", "；": ";",
        ".": ".", ",": ",", "?": "?", "!": "!",
    ]
}
