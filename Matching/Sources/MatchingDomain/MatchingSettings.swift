import Foundation

public nonisolated struct MatchingSettings: Equatable, Sendable {
    public static let defaultRounds = 10
    public static let `default` = MatchingSettings(showsPinyin: false, rounds: defaultRounds)

    /// Applies to every Hanzi tile at once, kept across lessons and launches.
    public var showsPinyin: Bool
    public var rounds: Int

    public init(showsPinyin: Bool, rounds: Int) {
        self.showsPinyin = showsPinyin
        self.rounds = rounds
    }
}
