import Foundation

public nonisolated struct GenerateExampleUseCase: Sendable {
    /// Han characters a generated sentence may have, as the bundled ones.
    public static let lengthLimit = 3...16
    /// Tries for one sentence: on the Mac's model, 小学生 was refused two times in three and
    /// passed the third.
    public static let attempts = 3

    public let generator: any ExampleGenerating

    public init(generator: any ExampleGenerating) {
        self.generator = generator
    }

    /// A sentence using the word in that sense, or nil. Nothing is asked for a meaning with no
    /// English to check. A refusal, or a sentence that leaves the word out, is in another
    /// script, runs long or has no translation, is tried again, up to `attempts` in all: a
    /// model can answer in the wrong script, with a synonym (看病 came back as 看医生 three
    /// times in three), or at length. No model at all is not tried again.
    public func callAsFunction(_ request: ExampleRequest) async throws -> ExampleSentence? {
        guard EnglishMeaning.isCheckable(request.meaning) else { return nil }
        for _ in 0..<Self.attempts {
            switch try await generator.example(for: request) {
            case .unavailable:
                return nil
            case .refused:
                continue
            case .written(let sentence):
                if Self.isFit(sentence, for: request) { return sentence }
            }
        }
        return nil
    }

    /// Whether a written sentence can be shown: it uses the word, is all Hanzi and
    /// punctuation, is short enough for a card, and has a translation.
    public static func isFit(_ sentence: ExampleSentence, for request: ExampleRequest) -> Bool {
        let hanzi = sentence.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        return hanzi.contains(request.hanzi)
            && lengthLimit.contains(hanzi.filter(isHan).count)
            && hanzi.allSatisfy { isHan($0) || $0.isPunctuation || $0.isWhitespace }
            && !sentence.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x2FFFF).contains($0.value) }
    }
}
