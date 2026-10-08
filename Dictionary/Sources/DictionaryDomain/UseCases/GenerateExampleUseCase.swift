import Foundation

public nonisolated struct GenerateExampleUseCase: Sendable {
    /// Han characters a generated sentence may have, as the bundled ones.
    public static let lengthLimit = 3...16

    public let generator: any ExampleGenerating

    public init(generator: any ExampleGenerating) {
        self.generator = generator
    }

    /// A sentence using the word in that sense, or nil. Nothing is asked for a meaning with no
    /// English to check, and a sentence is dropped unless it uses the word, is all Hanzi and
    /// punctuation, is short enough for a card, and has a translation: a model can answer in
    /// the wrong script, about something else, or at length.
    public func callAsFunction(_ request: ExampleRequest) async throws -> ExampleSentence? {
        guard EnglishMeaning.isCheckable(request.meaning),
              let sentence = try await generator.example(for: request)
        else { return nil }
        let hanzi = sentence.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        let han = hanzi.filter(Self.isHan)
        guard hanzi.contains(request.hanzi),
              Self.lengthLimit.contains(han.count),
              hanzi.allSatisfy({ Self.isHan($0) || $0.isPunctuation || $0.isWhitespace }),
              !sentence.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return sentence
    }

    static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x2FFFF).contains($0.value) }
    }
}
