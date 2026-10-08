import Foundation

/// English word order the on-device model gets wrong, put right. It glosses the Chinese order of
/// 我和妈妈, so writes "I and my mom" where English says "my mom and I", and no wording of the
/// prompt stopped it, so the fix is made here, for the shapes it was seen to write.
public nonisolated enum EnglishWordOrder {
    /// "I and my mom went" is "My mom and I went"; "I and you" is "You and I", "I and she" is
    /// "She and I". Anything else is left as it is.
    public static func speakerLast(_ english: String) -> String {
        let pattern = #"\bI and ((?:my|your|his|her|our|their|the) [A-Za-z]+|you|he|she|they)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return english }
        var text = english
        for match in regex.matches(in: english, range: NSRange(english.startIndex..., in: english)).reversed() {
            guard let whole = Range(match.range, in: text), let other = Range(match.range(at: 1), in: text) else { continue }
            let atStart = whole.lowerBound == text.startIndex
            var others = String(text[other])
            others = atStart ? others.prefix(1).uppercased() + others.dropFirst() : others
            text.replaceSubrange(whole, with: "\(others) and I")
        }
        return text
    }
}
