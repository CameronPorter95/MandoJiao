import Foundation
import VocabularyDomain

/// A whole lesson, fully decided up front: a fixed list of exercises, each one
/// a set of pairs to match.
public struct MatchingPlan: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let exercises: [[WordPair]]

    public init(id: UUID = UUID(), title: String, exercises: [[WordPair]]) {
        self.id = id
        self.title = title
        self.exercises = exercises
    }

    public var exerciseCount: Int { exercises.count }

    /// Every distinct pair the lesson touched, for the summary screen.
    public var distinctPairs: [WordPair] {
        var seen = Set<UUID>()
        return exercises.flatMap { $0 }.filter { seen.insert($0.id).inserted }
    }
}

public enum MatchingPlanBuilder {
    public static let pairsPerExercise = 5
    public static let exercisesPerLesson = 10

    /// Builds a lesson by dealing pairs out of a shuffled bag, refilling the bag
    /// when it runs dry. A pool smaller than `exerciseCount * pairsPerExercise`
    /// just means words come around again, which is the point.
    ///
    /// Within one exercise no two pairs share Hanzi or any meaning, so a board
    /// never has a tile that fits two answers.
    /// Returns `nil` when there are fewer than `pairsPerExercise` usable pairs.
    public static func makeLesson(
        title: String,
        from pool: [WordPair],
        exerciseCount: Int = exercisesPerLesson,
        pairsPerExercise: Int = pairsPerExercise
    ) -> MatchingPlan? {
        let unique = deduplicated(pool)
        guard exerciseCount > 0, pairsPerExercise > 0, unique.count >= pairsPerExercise else {
            return nil
        }

        var bag: [WordPair] = []
        var exercises: [[WordPair]] = []

        for _ in 0..<exerciseCount {
            var chosen: [WordPair] = []
            var deferred: [WordPair] = []
            var refills = 0

            while chosen.count < pairsPerExercise {
                if bag.isEmpty {
                    refills += 1
                    bag = (deferred + unique).shuffled()
                    deferred = []
                    bag.removeAll { candidate in
                        chosen.contains { $0.id == candidate.id }
                    }
                    // Can only happen if the pool shrank underneath us.
                    if bag.isEmpty { break }
                }

                let candidate = bag.removeFirst()
                if chosen.contains(where: { $0.id == candidate.id }) { continue }

                let readsTheSame = chosen.contains { $0.hanzi == candidate.hanzi || $0.sharesMeaning(with: candidate) }
                // After two passes the constraint is unsatisfiable for this pool,
                // so take the clash rather than spin forever.
                if readsTheSame && refills < 2 {
                    deferred.append(candidate)
                } else {
                    chosen.append(candidate)
                }
            }

            bag.append(contentsOf: deferred.shuffled())
            exercises.append(chosen.shuffled())
        }

        return MatchingPlan(title: title, exercises: exercises)
    }

    /// Collapses pairs that are the same word twice over, keeping the first.
    private static func deduplicated(_ pool: [WordPair]) -> [WordPair] {
        var seen = Set<String>()
        return pool.filter { pair in
            let english = pair.english.trimmingCharacters(in: .whitespacesAndNewlines)
            let hanzi = pair.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !english.isEmpty, !hanzi.isEmpty else { return false }
            return seen.insert("\(english.lowercased())|\(hanzi)").inserted
        }
    }
}

private extension WordPair {
    /// Any meaning, not just the headline on the tile: 行 showing "to walk" beside 可以
    /// showing "okay" is a board where "okay" fits both.
    func sharesMeaning(with other: WordPair) -> Bool {
        let theirs = Set(other.meanings.map { $0.lowercased() })
        return meanings.contains { theirs.contains($0.lowercased()) }
    }
}
