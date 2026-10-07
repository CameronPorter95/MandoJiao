import Foundation

/// A word the learner has saved, as the dictionary sees it: enough to tell which reading it
/// is and to open it again, and nothing else. The library supplies these, so the
/// dictionary never learns what a library word is.
public nonisolated struct SavedReading: Hashable, Sendable {
    public let id: UUID
    public let hanzi: String
    public let pinyin: String

    public init(id: UUID, hanzi: String, pinyin: String) {
        self.id = id
        self.hanzi = hanzi
        self.pinyin = pinyin
    }
}

/// The learner's saved words, live. Implemented outside the dictionary and handed in.
public nonisolated protocol SavedReadingsRepository: Sendable {
    func savedReadings() -> AsyncStream<[SavedReading]>
}

/// What tapping a reading's vocabulary button asks for: adding it, or opening the saved word.
public nonisolated enum ReadingEdit: Identifiable, Hashable, Sendable {
    case add(DictionaryEntry)
    case open(SavedReading)

    public var id: String {
        switch self {
        case .add(let entry): "add \(entry.simplified) \(entry.pinyin)"
        case .open(let saved): saved.id.uuidString
        }
    }
}

public nonisolated extension DictionaryEntry {
    /// Whether a word saved with this Hanzi and pinyin is this reading, however the pinyin
    /// was typed: "yin2 hang2" is yínháng. A word saved without pinyin is no reading in
    /// particular.
    func isReading(hanzi: String, pinyin: String) -> Bool {
        hanzi == simplified && !pinyin.isEmpty && Self.spelling(pinyin) == Self.spelling(self.pinyin)
    }

    /// The letters, and the tones in the order written, so marks and numbers compare alike.
    /// A 5 for the neutral tone is dropped, as a neutral tone is written with no mark.
    private static func spelling(_ pinyin: String) -> (letters: String, tones: [Int]) {
        var letters = String.UnicodeScalarView()
        var tones: [Int] = []
        for scalar in pinyin.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x304: tones.append(1)
            case 0x301: tones.append(2)
            case 0x30C: tones.append(3)
            case 0x300: tones.append(4)
            case 0x31...0x34: tones.append(Int(scalar.value) - 0x30)
            case 0x300...0x36F: continue
            default: if scalar.properties.isAlphabetic { letters.append(scalar) }
            }
        }
        return (String(letters), tones)
    }
}
