import Foundation

/// A dictionary sense made short enough for a tile or a suggestion.
public nonisolated enum Gloss {
    /// Asides dropped, unless the sense is only an aside, like 了's "(completed action
    /// marker)", then cut to whole senses or words within `limit` characters.
    public static func plain(_ sense: String, limit: Int = 40) -> String {
        var text = strippingAsides(sense).trimmingCharacters(in: .whitespaces)
        if text.isEmpty, sense.hasPrefix("("), sense.hasSuffix(")") {
            text = String(sense.dropFirst().dropLast())
        }
        text = text
            .replacingOccurrences(of: "\\s+([,;])", with: "$1", options: .regularExpression)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;."))
        return shortened(text, limit: limit)
    }

    private static func strippingAsides(_ text: String) -> String {
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

    private static func shortened(_ text: String, limit: Int) -> String {
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
}
