import CoreDesignSystem
import SwiftUI

/// Start lesson, opening a menu of exercises rather than starting one, so every exercise
/// is a tap away and nothing is added to the screen. An exercise there are too few words
/// for is shown but disabled.
struct StartLessonMenu: View {
    let canStart: (LessonExercise) -> Bool
    let onStart: (LessonExercise) -> Void

    var body: some View {
        Menu {
            ForEach(LessonExercise.allCases, id: \.self) { exercise in
                Button { onStart(exercise) } label: {
                    Label(exercise.title, systemImage: exercise.systemImage)
                }
                .disabled(!canStart(exercise))
            }
        } label: {
            Text("Start lesson")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .disabled(!LessonExercise.allCases.contains(where: canStart))
    }
}
