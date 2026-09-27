import CoreDesignSystem
import CoreUI
import MatchingDomain
import SwiftUI
import VocabularyDomain

/// The matching lesson: progress, the current board, and the review once it ends.
///
/// Mirrors `SpeakingScreen` deliberately, down to the quit confirmation, so the two
/// lessons behave the same at the edges.
struct MatchingScreen: View {
    let state: MatchingState
    let onAction: (MatchingAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let lesson = state.lesson {
                header(lesson)

                if lesson.isFinished {
                    LessonCompleteView(
                        results: results(for: lesson),
                        onPractiseAgain: { onAction(.practiseAgainTapped) },
                        onDone: { onAction(.closeTapped) }
                    )
                    .transition(.opacity)
                } else {
                    board(lesson)
                }
            } else {
                notEnoughWords
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .confirmationDialog(
            "Quit this lesson?",
            isPresented: Binding(
                get: { state.isConfirmingQuit },
                set: { if !$0 { onAction(.quitCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) { onAction(.quitConfirmed) }
            Button("Keep practising", role: .cancel) { onAction(.quitCancelled) }
        } message: {
            Text("Mistakes so far are still added to your mistakes list.")
        }
    }

    // MARK: - Pieces

    private func header(_ lesson: MatchingLesson) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button {
                    onAction(.closeTapped)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close lesson")

                LessonProgressBar(progress: lesson.progress, exerciseCount: lesson.plan.exerciseCount)

                Text("\(lesson.exerciseNumber)/\(lesson.plan.exerciseCount)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if !lesson.isFinished {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tap the matching pairs")
                            .font(.title2.bold())
                        Text(state.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    pinyinToggle
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    /// Applies to every Hanzi tile on the board at once, rather than revealing
    /// one card at a time.
    private var pinyinToggle: some View {
        Button {
            onAction(.pinyinToggled)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: state.showsPinyin ? "eye.fill" : "eye.slash")
                Text("pīnyīn")
            }
            .font(.footnote.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(state.showsPinyin ? Theme.accent : .secondary)
        .accessibilityLabel(state.showsPinyin ? "Hide pinyin" : "Show pinyin")
    }

    private func board(_ lesson: MatchingLesson) -> some View {
        VStack {
            Spacer(minLength: 0)
            MatchingBoardView(board: lesson.board, showsPinyin: state.showsPinyin) { tile in
                onAction(.tileTapped(tile))
            }
            .id(lesson.exerciseIndex)
            .transition(.opacity)
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: lesson.exerciseIndex)
    }

    private var notEnoughWords: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Not enough words yet")
                .font(.title3.bold())
            Text("A lesson needs at least \(MatchingPlanBuilder.pairsPerExercise) words. Add a few more to the library and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { onAction(.closeTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer()
        }
    }

    private func results(for lesson: MatchingLesson) -> LessonCompleteView.Results {
        LessonCompleteView.Results(
            total: lesson.totalMatches,
            totalLabel: "matches",
            missCount: lesson.missCount,
            missedPairs: lesson.missedPairs.map { (pair: $0.pair.reviewRow, misses: $0.misses) },
            cleanPairs: lesson.cleanPairs.map(\.reviewRow)
        )
    }
}

extension WordPair {
    var reviewRow: LessonCompleteView.Row {
        LessonCompleteView.Row(id: id, hanzi: hanzi, english: meanings.joined(separator: "; "), pinyin: pinyin)
    }
}

#Preview("Board") {
    MatchingScreen(
        state: MatchingState(
            title: "All words",
            lesson: MatchingPlanBuilder.makeLesson(title: "All words", from: SampleVocabulary.previewPairs)
                .map(MatchingLesson.init(plan:)),
            showsPinyin: true
        ),
        onAction: { _ in }
    )
}

#Preview("Not enough words") {
    MatchingScreen(state: MatchingState(title: "Small deck"), onAction: { _ in })
}
