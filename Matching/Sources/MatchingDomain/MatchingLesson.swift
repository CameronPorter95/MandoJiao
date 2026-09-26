import Foundation
import VocabularyDomain

/// A matching lesson's progress: the current board, the tallies, and the move to the
/// next board once one is cleared.
///
/// A value with no timers or sound. `MatchingViewModel` owns the pause after a cleared
/// board and the tones, so the tallying rules are exercised without either.
public struct MatchingLesson: Equatable {
    public let plan: MatchingPlan

    public private(set) var exerciseIndex = 0
    public private(set) var board: MatchingBoard
    public private(set) var isFinished = false
    public private(set) var missCount = 0

    /// How many times each pair was part of a wrong guess in this lesson.
    public private(set) var missesByPairID: [UUID: Int] = [:]
    /// How many times each pair was solved on a board where it had not been
    /// guessed wrong. Used to retire words from the mistakes list.
    public private(set) var cleanSolvesByPairID: [UUID: Int] = [:]

    public init(plan: MatchingPlan) {
        self.plan = plan
        self.board = MatchingBoard(pairs: plan.exercises.first ?? [])
    }

    public var exerciseNumber: Int { min(exerciseIndex + 1, plan.exerciseCount) }

    /// Whole-lesson progress, nudged along by each match inside the current
    /// board so the bar keeps moving mid-exercise.
    public var progress: Double {
        guard plan.exerciseCount > 0 else { return 0 }
        if isFinished { return 1 }
        let pairCount = max(board.pairs.count, 1)
        let withinBoard = Double(board.matchedCount) / Double(pairCount)
        return (Double(exerciseIndex) + withinBoard) / Double(plan.exerciseCount)
    }

    /// The words this lesson got wrong, most-missed first, for the review screen.
    public var missedPairs: [(pair: WordPair, misses: Int)] {
        let byID = Dictionary(
            plan.distinctPairs.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return missesByPairID
            .compactMap { id, misses in byID[id].map { (pair: $0, misses: misses) } }
            .sorted {
                $0.misses == $1.misses ? $0.pair.english < $1.pair.english : $0.misses > $1.misses
            }
    }

    /// Every distinct pair the lesson touched that it never got wrong, alphabetically.
    public var cleanPairs: [WordPair] {
        let missed = Set(missesByPairID.keys)
        return plan.distinctPairs
            .filter { !missed.contains($0.id) }
            .sorted { $0.english < $1.english }
    }

    /// How many matches the lesson asks for in all.
    public var totalMatches: Int { plan.exercises.reduce(0) { $0 + $1.count } }

    /// Taps on a finished lesson, or on a cleared board waiting to move on, are ignored.
    public mutating func tap(_ tile: Tile) -> TapResult {
        guard !isFinished, !board.isComplete else { return .ignored }

        let result = board.tap(tile)
        switch result {
        case .matched(_, _, let wasMissedEarlier):
            if !wasMissedEarlier {
                cleanSolvesByPairID[tile.pairID, default: 0] += 1
            }
        case .missed(let tiles):
            missCount += 1
            for missed in tiles {
                missesByPairID[missed.pairID, default: 0] += 1
            }
        case .selected, .switched, .deselected, .ignored:
            break
        }
        return result
    }

    /// Moves to the next board, or finishes after the last one.
    public mutating func advance() {
        guard !isFinished else { return }
        let next = exerciseIndex + 1
        guard next < plan.exercises.count else {
            isFinished = true
            return
        }
        exerciseIndex = next
        board = MatchingBoard(pairs: plan.exercises[next])
    }
}
