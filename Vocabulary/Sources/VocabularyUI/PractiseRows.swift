import CoreDesignSystem
import SwiftUI

/// One row per exercise, each starting it, for a list's Practise section. Every exercise is
/// in view and one tap away, where a single Start lesson button that opened a menu hid them
/// behind what looked like the action itself. A row there are too few words for is disabled
/// and says how many it needs.
struct PractiseRows: View {
    let wordCount: Int
    let minimumMatchingWords: Int
    let onStart: (LessonExercise) -> Void

    var body: some View {
        ForEach(LessonExercise.allCases, id: \.self) { exercise in
            let needed = exercise.minimumWords(matching: minimumMatchingWords)
            let isAvailable = wordCount >= needed
            Button { onStart(exercise) } label: {
                HStack(spacing: 14) {
                    Image(systemName: exercise.systemImage)
                        .font(.title3)
                        .foregroundStyle(isAvailable ? Theme.accent : Color.secondary)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.title)
                            .foregroundStyle(isAvailable ? Color.primary : Color.secondary)
                        Text(isAvailable ? exercise.detail : "Needs \(needed) \(needed == 1 ? "word" : "words")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .accessibilityHint(exercise.detail)
        }
    }
}
