import SwiftUI

struct LessonProgressBar: View {
    /// 0 to 1 across the whole lesson.
    let progress: Double
    let exerciseCount: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, min(1, progress)) * geometry.size.width)

                // Tick per exercise, so it is clear how much of the lesson is left.
                HStack(spacing: 0) {
                    ForEach(1..<max(exerciseCount, 1), id: \.self) { _ in
                        Spacer()
                        Rectangle()
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: 1)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.25), value: progress)
    }
}

#Preview {
    LessonProgressBar(progress: 0.42, exerciseCount: 10)
        .padding()
}
