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

    /// Bumped on every tap so views can hang haptics off it.
    private(set) var feedbackToken = 0
    private(set) var lastResult: TapResult?

    private let sounds: MatchSoundPlaying
    private var isAdvancing = false

    /// Long enough for the last tile to read as matched, short enough that it
    /// never feels like waiting.
    private let advanceDelay: Duration = .milliseconds(320)

    init(plan: LessonPlan, sounds: MatchSoundPlaying = ToneEngine.shared) {
        self.plan = plan
        self.sounds = sounds
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

    func tap(_ tile: Tile) {
        guard !isFinished, !isAdvancing else { return }

        let result = board.tap(tile)

        switch result {
        case .matched(let step, let boardComplete):
            sounds.playMatch(step: step, of: board.pairs.count)
            if boardComplete { scheduleAdvance() }
        case .missed:
            missCount += 1
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
