import Foundation

public nonisolated struct SpeakingSettings: Equatable, Sendable {
    public static let defaultCardLimit = 20
    public static let cardLimitRange = 5...40
    public static let `default` = SpeakingSettings(strictness: .default, cardLimit: defaultCardLimit)

    public var strictness: AnswerStrictness
    public var cardLimit: Int

    public init(strictness: AnswerStrictness, cardLimit: Int) {
        self.strictness = strictness
        self.cardLimit = cardLimit
    }
}
