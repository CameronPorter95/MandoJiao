import Foundation

/// A whole lesson, fully decided up front: a fixed list of exercises, each one
/// a set of pairs to match.
struct LessonPlan: Identifiable, Hashable {
    let id: UUID
    let title: String
    let exercises: [[WordPair]]

    init(id: UUID = UUID(), title: String, exercises: [[WordPair]]) {
        self.id = id
        self.title = title
        self.exercises = exercises
    }

    var exerciseCount: Int { exercises.count }

    /// Every distinct pair the lesson touched, for the summary screen.
    var distinctPairs: [WordPair] {
        var seen = Set<UUID>()
        return exercises.flatMap { $0 }.filter { seen.insert($0.id).inserted }
    }
}

enum LessonBuilder {
    static let pairsPerExercise = 5
    static let exercisesPerLesson = 10

    /// Builds a lesson by dealing pairs out of a shuffled bag, refilling the bag
    /// when it runs dry. A pool smaller than `exerciseCount * pairsPerExercise`
    /// just means words come around again, which is the point.
    ///
    /// Within one exercise no two pairs share an English or Hanzi string, so a
    /// board never has two identical-looking tiles with different answers.
    /// Returns `nil` when there are fewer than `pairsPerExercise` usable pairs.
    static func makeLesson(
        title: String,
        from pool: [WordPair],
        exerciseCount: Int = exercisesPerLesson,
        pairsPerExercise: Int = pairsPerExercise
    ) -> LessonPlan? {
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

                let readsTheSame = chosen.contains {
                    $0.english == candidate.english || $0.hanzi == candidate.hanzi
                }
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

        return LessonPlan(title: title, exercises: exercises)
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
