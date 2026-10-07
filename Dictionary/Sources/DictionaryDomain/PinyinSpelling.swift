import Foundation

/// Pinyin as its letters and the tones written on them, by mark or by a number after a
/// syllable or its vowel. A tone belongs to its syllable's vowels rather than to one letter,
/// so "shuǐ", "shui3" and "shu3i" all write the third tone on "ui".
public nonisolated struct PinyinSpelling: Hashable, Sendable {
    /// Lowercased, toneless and unspaced: "Yín háng" is "yinhang".
    public let letters: String
    /// Per letter, the tones written on its run of vowels, one bit each for tones 1 to 4.
    private let tones: [UInt8]
    /// The runs of vowels a tone is written on, which a query holding this spelling needs
    /// matched.
    private let written: [Run]

    private struct Run: Hashable, Sendable {
        let letters: Range<Int>
        let tones: UInt8
    }

    public init(_ pinyin: String) {
        var letters = String.UnicodeScalarView()
        var vowels: [Bool] = []
        var marks: [UInt8] = []
        var starts: [Bool] = []
        var syllable = 0
        for scalar in pinyin.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if let tone = Self.tone(marked: scalar) {
                if !marks.isEmpty { marks[marks.count - 1] |= tone }
            } else if (0x300...0x36F).contains(scalar.value) {
                continue
            } else if scalar.properties.isAlphabetic {
                letters.append(scalar)
                vowels.append(Self.vowels.contains(scalar))
                marks.append(0)
                starts.append(marks.count - 1 == syllable)
            } else {
                if (0x31...0x34).contains(scalar.value), syllable < marks.count {
                    let vowel = (syllable..<marks.count).last { vowels[$0] }
                    marks[vowel ?? marks.count - 1] |= UInt8(1) << UInt8(scalar.value - 0x31)
                }
                syllable = marks.count
            }
        }
        var tones = [UInt8](repeating: 0, count: marks.count)
        var written: [Run] = []
        var start = 0
        while start < marks.count {
            var end = start + 1
            if vowels[start] {
                while end < marks.count, !starts[end], vowels[end] { end += 1 }
            }
            let run = start..<end
            let mask = run.reduce(0) { $0 | marks[$1] }
            if mask != 0 {
                for index in run { tones[index] = mask }
                written.append(Run(letters: run, tones: mask))
            }
            start = end
        }
        self.letters = String(letters)
        self.tones = tones
        self.written = written
    }

    /// The same letters, carrying every tone the query writes.
    public func isSpelt(as query: PinyinSpelling) -> Bool {
        letters == query.letters && carries(query, at: 0)
    }

    public func hasPrefix(_ query: PinyinSpelling) -> Bool {
        letters.hasPrefix(query.letters) && carries(query, at: 0)
    }

    public func contains(_ query: PinyinSpelling) -> Bool {
        let mine = Array(letters)
        let theirs = Array(query.letters)
        guard theirs.count <= mine.count else { return false }
        return (0...(mine.count - theirs.count)).contains { offset in
            mine[offset..<(offset + theirs.count)].elementsEqual(theirs) && carries(query, at: offset)
        }
    }

    /// A query's tone may sit on any vowel of the run here, so "shúi" finds shuí, but a run
    /// here spanning two syllables carries both their tones.
    private func carries(_ query: PinyinSpelling, at offset: Int) -> Bool {
        query.written.allSatisfy { run in
            run.letters.reduce(0) { $0 | tones[offset + $1] } & run.tones == run.tones
        }
    }

    private static let vowels: Set<Unicode.Scalar> = ["a", "e", "i", "o", "u", "v"]

    /// A breve is taken for the caron it is often typed as.
    private static func tone(marked scalar: Unicode.Scalar) -> UInt8? {
        switch scalar.value {
        case 0x304: 1 << 0
        case 0x301: 1 << 1
        case 0x30C, 0x306: 1 << 2
        case 0x300: 1 << 3
        default: nil
        }
    }
}
