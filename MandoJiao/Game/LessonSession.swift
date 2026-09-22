import Foundation
import Observation

/// Drives one lesson: the current board, the sounds, and the hop to the next
/// exercise once a board is cleared.
@MainActor
@Observable
final class LessonSession {
    let plan: LessonPlan

    private(set) var exerciseIndex = 0
    private(set) var board: MatchBoard
    private(set) var isFinished = false
    private(set) var missCount = 0

    /// How many times each pair was part of a wrong guess in this lesson.
    private(set) var missesByPairID: [UUID: Int] = [:]
    /// How many times each pair was solved on a board where it had not been
    /// guessed wrong. Used to retire words from the mistakes list.
    private(set) var cleanSolvesByPairID: [UUID: Int] = [:]

    /// Bumped on every tap so views can hang haptics off it.
    private(set) var feedbackToken = 0
    private(set) var lastResult: TapResult?

    private let sounds: MatchSoundPlaying
    private var isAdvancing = false

    /// Long enough for the last tile to read as matched, short enough that it
    /// never feels like waiting.
    private let advanceDelay: Duration = .milliseconds(320)

    /// `sounds` defaults inside the body rather than in the signature, because a
    /// default argument referring to a main actor value is evaluated in the
    /// caller's context.
    init(plan: LessonPlan, sounds: MatchSoundPlaying? = nil) {
        self.plan = plan
        self.sounds = sounds ?? MatchSounds.shared
        self.board = MatchBoard(pairs: plan.exercises.first ?? [])
    }

    var exerciseNumber: Int { min(exerciseIndex + 1, plan.exerciseCount) }

    /// Whole-lesson progress, nudged along by each match inside the current
    /// board so the bar keeps moving mid-exercise.
    var progress: Double {
        guard plan.exerciseCount > 0 else { return 0 }
        if isFinished { return 1 }
        let pairCount = max(board.pairs.count, 1)
        let withinBoard = Double(board.matchedCount) / Double(pairCount)
        return (Double(exerciseIndex) + withinBoard) / Double(plan.exerciseCount)
    }

    /// The words this lesson got wrong, most-missed first, for the review screen.
    var missedPairs: [(pair: WordPair, misses: Int)] {
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

    func tap(_ tile: Tile) {
        guard !isFinished, !isAdvancing else { return }

        let result = board.tap(tile)

        switch result {
        case .matched(let step, let boardComplete, let wasMissedEarlier):
            if !wasMissedEarlier {
                cleanSolvesByPairID[tile.pairID, default: 0] += 1
            }
            sounds.playMatch(step: step, of: board.pairs.count)
            if boardComplete { scheduleAdvance() }
        case .missed(let tiles):
            missCount += 1
            for missed in tiles {
                missesByPairID[missed.pairID, default: 0] += 1
            }
            sounds.playMiss()
        case .selected, .switched, .deselected, .ignored:
            break
        }

        lastResult = result
        feedbackToken += 1
    }

    private func scheduleAdvance() {
        isAdvancing = true
        Task { [advanceDelay] in
            try? await Task.sleep(for: advanceDelay)
            self.advance()
        }
    }

    private func advance() {
        isAdvancing = false
        let next = exerciseIndex + 1
        guard next < plan.exercises.count else {
            isFinished = true
            sounds.playLessonComplete()
            return
        }
        exerciseIndex = next
        board = MatchBoard(pairs: plan.exercises[next])
    }
}
