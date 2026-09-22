import Foundation
import SwiftData

/// Writes a finished lesson's mistakes back onto the stored words.
@MainActor
enum MistakeLog {
    /// A word missed during the lesson has its mistakes recorded, and takes no
    /// credit for solving it later in that same lesson: getting it right after
    /// getting it wrong is not the same as knowing it.
    ///
    /// A word that came up clean, having been on the mistakes list already,
    /// works its way back off it.
    static func apply(
        misses: [UUID: Int],
        cleanSolves: [UUID: Int],
        in context: ModelContext
    ) {
        guard !misses.isEmpty || !cleanSolves.isEmpty else { return }
        guard let words = try? context.fetch(FetchDescriptor<VocabWord>()) else { return }

        var changed = false

        for word in words {
            if let missed = misses[word.uuid], missed > 0 {
                word.missCount += missed
                word.lastMissedAt = .now
                changed = true
                continue
            }

            if let solved = cleanSolves[word.uuid], solved > 0, word.missCount > 0 {
                word.missCount = max(0, word.missCount - solved)
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
    }

    static func clearAll(in context: ModelContext) {
        guard let words = try? context.fetch(FetchDescriptor<VocabWord>()) else { return }
        for word in words where word.missCount > 0 {
            word.missCount = 0
            word.lastMissedAt = nil
        }
        try? context.save()
    }
}
